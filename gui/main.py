# Check for required modules:
import sys
import os
if 'ACC_LOCAL_DIR' in os.environ.keys():
  sys.path.append(os.environ['ACC_LOCAL_DIR']+'/tao/python/tao_pexpect')
else:
  sys.path.append(os.environ['ACC_ROOT_DIR']+'/tao/python/tao_pexpect')
from module_check import module_check
module_check()

import tkinter as tk
from tkinter import messagebox
from tkinter import filedialog
from tao_widget import *
from tao_set import tao_set
from parameters import str_to_tao_param
from parameters import tao_parameter_dict
from tao_windows import *
import string




#---------------------------------------------------------------
# Root window

class tao_root_window(tk.Tk):

  def __init__(self, *args, **kwargs):
    tk.Tk.__init__(self)

    from tkinter import font
    self.title("Tao")
    self.protocol("WM_DELETE_WINDOW", self.quit_cmd)
    self.tk.call('tk', 'scaling', 1.0)
    #default_font = font.nametofont("TkDefaultFont")
    #default_font.configure(size=14)
    #self.option_add("*Font", default_font)

    # Menu bar
    self.menubar_init()

    # Init GUI

    init_frame = tk.Frame(self)
    init_frame.pack()
    self.tao_load(init_frame)

    # Dictionary of where template plots have been placed
    #self.placed = {}
    # List of plot windows (accessible for refreshing)
    self.plot_windows = []

    # Key bindings

    self.bind_all("<Control-q>", self.quit_cmd)

  #-------------------------
  # Tao startup

  def start_main(self):
    self.unbind_all("<Return>")
    self.lift()
    self.focus_force()
    self.menubar.entryconfig("File", state="normal")
    self.menubar.entryconfig("Window", state="normal")
    self.main_frame = tk.Frame(self, width = 20, height = 30)
    self.main_frame.pack()
    self.bind_all('<Control-g>', self.global_vars_event)

    # Call
    tk.Label(self.main_frame, text="Call command file:").grid(row=0, column=0)
    self.call_file = tk_tao_parameter(str_to_tao_param("call_file;FILE;T;"), self.main_frame, self.pipe)
    self.call_file.tk_wid.grid(row=0, column=1, sticky='EW')
    tk.Button(self.main_frame, text="Run", command=self.tao_call).grid(row=0, column=2, sticky='EW')
    # Arguments
    tk.Label(self.main_frame, text="Arguments:").grid(row=1, column=0)
    self.cf_args = tk_tao_parameter(str_to_tao_param("cf_args;STR;T;"), self.main_frame, self.pipe)
    self.cf_args.tk_wid.configure(width=30)
    self.cf_args.tk_wid.bind("<Return>", self.tao_call)
    self.cf_args.tk_wid.grid(row=1, column=1, columnspan=2, sticky='EW')

    # Optimization
    tk.Label(self.main_frame, text="Optimization:").grid(row=2, column=0)
    tk.Button(self.main_frame, text="Setup").grid(row=2, column=1, sticky='EW')
    tk.Button(self.main_frame, text="Run").grid(row=2, column=2, sticky='EW')

    # Command line
    self.cmd_frame = tk.Frame(self)
    self.cmd_frame.pack(side="bottom", fill="x")
    self.history = [] #holds the history
    self.history.append([]) #Tao and shell history
    self.history_pos = 0 #Used for scrolling in history on command line
    self.history.append([]) #Call history
    tk.Button(self.cmd_frame, text="View History...", command=self.view_history_cmd).pack(side="top", fill="x")

    self.command = tk_tao_parameter(str_to_tao_param("command;STR;T;"), self.cmd_frame, self.pipe)
    self.command.tk_wid.bind("<Return>", self.tao_command)
    self.command.tk_wid.bind("<Shift-Return>", self.tao_spawn)
    self.command.tk_wid.bind("<Up>", self.hist_scroll_up)
    self.command.tk_wid.bind("<Down>", self.hist_scroll_down)
    self.command.tk_wid.pack(side="left", fill="x", expand=1)
    tk.Button(self.cmd_frame, text="Run (System Shell)", command=self.tao_spawn).pack(side="right")
    tk.Button(self.cmd_frame, text="Run (Tao)", command=self.tao_command).pack(side="right")

  def hist_scroll_up(self, event=None):
    if len(self.history[0]) > self.history_pos: #if there's room left to scroll up in history
      self.history_pos += 1
      self.command.tk_var.set(self.history[0][-1*self.history_pos])
      self.command.tk_wid.icursor(len(self.command.tk_var.get()))

  def hist_scroll_down(self, event=None):
    if self.history_pos > 0:
      self.history_pos -= 1
      if self.history_pos > 0:
        self.command.tk_var.set(self.history[0][-1*self.history_pos])
      else:
        self.command.tk_var.set("")
      self.command.tk_wid.icursor(len(self.command.tk_var.get()))

  def tao_command(self, event=None):
    '''
    Runs the text in self.command at the Tao command line, appends it to the history, and clears self.command
    '''
    if self.command.tk_var.get() != "":
      self.pipe.cmd(self.command.tk_var.get())
      self.history[0].append(self.command.tk_var.get())
      self.command.tk_var.set("")
    self.history_pos = 0
    #Try to refresh history window
    try:
      self.history_window.refresh()
    except:
      pass

  def tao_spawn(self, event=None):
    '''
    Runs the text in self.command at the system command line, appends it to the history, and clears self.command
    '''
    if self.command.tk_var.get() != "":
      cmd_txt = self.command.tk_var.get()
      self.command.tk_var.set("spawn " + cmd_txt)
      self.tao_command()

  def tao_call(self, event=None):
    '''
    Runs the command file in self.call_file, appends it to the history, and clears self.call_file
    '''
    if self.call_file.tk_var.get() != "Browse...":
      self.pipe.cmd("call " + self.call_file.tk_var.get() + ' ' + self.cf_args.tk_var.get())
      self.history[1].append(self.call_file.tk_var.get())
      self.call_file.tk_var.set("Browse...")
    #Try to refresh history window
    try:
      self.history_window.refresh()
    except:
      pass

  def menubar_init(self):
    self.menubar = tk.Menu(self)

    file_menu = tk.Menu(self.menubar)
    file_menu.add_command(label = 'Read...', command = self.read_cmd)
    file_menu.add_command(label = 'Write...', command = self.write_cmd)
    file_menu.add_command(label = 'Reinit...', command = self.reinit_cmd)
    file_menu.add_separator()
    file_menu.add_command(label = 'Quit', command = self.quit_cmd, accelerator = 'Ctrl+Q')
    self.menubar.add_cascade(label = 'File', menu = file_menu)

    window_menu = tk.Menu(self.menubar)
    window_menu.add_command(label = 'Optimizer...', command = self.optimizer_cmd)
    window_menu.add_command(label = 'Plot Templates...', command = self.plot_template_cmd)
    window_menu.add_command(label = 'Active Plots...', command = self.plot_region_cmd)
    window_menu.add_command(label = 'Wave...', command = self.wave_cmd)
    window_menu.add_command(label = 'Variables...', command = self.view_vars_cmd)
    window_menu.add_command(label = 'Global Variables...', command = self.set_global_vars_cmd)
    window_menu.add_command(label = 'Data...', command = self.view_data_cmd)
    window_menu.add_command(label = 'Elements...', command = self.view_ele_cmd)
    window_menu.add_command(label = 'Lattice...', command = self.view_lattice_cmd)
    self.menubar.add_cascade(label = 'Window', menu = window_menu)

    self.config(menu=self.menubar)

  def default_plots(self):
    '''
    If self.plot_mode == "matplotlib", opens all the
    plot templates listed in plot.gui.init in
    separate matplotlib windows
    '''
    if self.plot_mode == "matplotlib":
      # Open plot.gui.init
      try:
        plot_file = open('plot.gui.init')
        plot_list = plot_file.read()
        plot_list = plot_list.splitlines()
        plot_file.close()
      except:
        plot_list = []

      # Get list of plot templates to check input against
      plot_templates = self.pipe.cmd_in("python plot_list t")
      plot_templates = plot_templates.splitlines()
      for i in range(len(plot_templates)):
        plot_templates[i] = plot_templates[i].split(';')[1]

      # Validate entries in plot.gui.init
      for plot in plot_list:
        if plot in plot_templates:
          # Make a window for the plot
          win = tao_plot_window(self, plot, self.pipe)
          self.plot_windows.append(win)

  def tao_load(self,init_frame):
    self.menubar.entryconfig("File", state="disabled")
    self.menubar.entryconfig("Window", state="disabled")
    from parameters import param_dict
    tk_list = [] #Items: tk_tao_parameter()'s (see tao_widget.py)
    init_frame.grid_columnconfigure(0, weight=1, pad=10)
    init_frame.grid_columnconfigure(1, weight=1)

    #Look for and read gui.init
    #gui.init should be in the same directory that
    #main.py is run from
    #each line should have the form
    #parameter:value
    #E.g. init_file:tao.init
    #E.g. rf_on:T
    try:
      init_file = open('gui.init')
      init_list = init_file.read()
      init_list = init_list.splitlines()
      init_file.close()
    except:
      init_list = []
    init_dict = {}
    for entry in init_list:
      entry = entry.strip()
      #Check for proper formatting and not a comment
      if entry.find(':') != -1 & entry.find('#') != 0:
        name = entry[:entry.find(':')]
        name = name.strip()
        value = entry[entry.find(':')+1:]
        value = value.strip()
        init_dict[name] = value
      else:
        continue
      c1 = (name in ["tao_exe", "tao_lib"])
      try:
        c2 = (param_dict[name].type == 'FILE')
      except KeyError:
        c2 = False
      if c1 | c2:
        #Check that a good filename has been given
        try:
          filename = init_dict[name]
          #Expand environment variables and ~
          filename = os.path.expanduser(filename)
          filename = os.path.expandvars(filename)
          f = open(filename)
          f.close()
          init_dict[name] = filename
        except:
          messagebox.showwarning(tk_list[k].param.name, "File not found: " + filename)
          init_dict.pop(name)
          #Remove bad files from init dict
    k = 0 #row number counter
    for param, tao_param in param_dict.items():
      tk_list.append(tk_tao_parameter(tao_param,init_frame))
      #Possibly set value from init file
      if tk_list[k].param.name in init_dict:
        if tk_list[k].param.type == 'FILE':
          tk_list[k].tk_var.set(init_dict[tk_list[k].param.name])
        elif tk_list[k].param.type == 'LOGIC':
          state = (init_dict[tk_list[k].param.name] == 'T') | (init_dict[tk_list[k].param.name] == 'True')
          tk_list[k].tk_var.set(state)
      tk.Label(init_frame,text=param).grid(row=k,sticky="E")
      tk_list[k].tk_wid.grid(row=k, column=1, sticky="W")
      k = k+1
    # Choosing whether to use pexpect or ctypes must be handled separately
    tk.Label(init_frame, text="Choose interface").grid(row=k, sticky="E")
    def swap_box(event=None):
      if chosen_interface.get() == "pexpect":
        ctype_label.grid_forget()
        tao_lib.tk_wid.grid_forget()
        pexp_label.grid(row=k+1, sticky="E")
        tao_exe.tk_wid.grid(row=k+1, column=1, sticky="W")
      elif chosen_interface.get() == "ctypes":
        pexp_label.grid_forget()
        tao_exe.tk_wid.grid_forget()
        ctype_label.grid(row=k+1, sticky="E")
        tao_lib.tk_wid.grid(row=k+1, column=1, sticky="W")

    chosen_interface = tk.StringVar()
    chosen_interface.set("pexpect")
    if "chosen_interface" in init_dict:
      if init_dict["chosen_interface"] in ["pexpect", "ctypes"]:
        chosen_interface.set(init_dict["chosen_interface"])
    tk.OptionMenu(init_frame, chosen_interface, "pexpect", "ctypes", command=swap_box).grid(row=k, column=1, sticky="W")
    pexp_label = tk.Label(init_frame, text="Tao executable")
    ctype_label = tk.Label(init_frame, text="Shared Library")
    tao_exe = tk_tao_parameter(str_to_tao_param("tao_exe;FILE;T;"), init_frame)
    if "tao_exe" in init_dict:
      tao_exe.tk_var.set(init_dict["tao_exe"])
    tao_lib = tk_tao_parameter(str_to_tao_param("tao_lib;FILE;T;"), init_frame)
    if "tao_lib" in init_dict:
      tao_exe.tk_var.set(init_dict["tao_lib"])
    swap_box()

    #Choosing plot mode must also be handled separately
    tk.Label(init_frame, text="Plotting Mode").grid(row=k+2, sticky='E')
    plot_mode = tk.StringVar()
    plot_mode.set("matplotlib")
    plot_options = ["matplotlib", "pgplot", "None"]
    plot_chooser = tk.OptionMenu(init_frame, plot_mode, *plot_options)
    plot_chooser.grid(row=k+2, column=1, sticky='W')
    # Set plot_mode from init_dict if specified
    if "plot_mode" in init_dict:
      if init_dict["plot_mode"] in plot_options:
        plot_mode.set(init_dict["plot_mode"])

    def param_load(event=None):
      if chosen_interface.get() == "ctypes":
        messagebox.showwarning("Error", "ctypes is not currently supported.  Please use pexpect.")
        return 0
      # set the font
      try:
        new_size = int(font_var.get())
        new_font = font.nametofont("TkDefaultFont")
        new_font.configure(size=new_size)
        self.option_add("*Font", new_font)
      except:
        pass
      # set self.lw
      self.lw = lw_var.get()
      self.plot_mode = plot_mode.get()
      init_args = ""
      for tk_param in tk_list:
        if tk_param.param.type in ['STR','ENUM']:
          tk_param.param.value = tk_param.tk_var.get()
          if tk_param.param.value != "":
            init_args = init_args + "-" + tk_param.param.name + " " + tk_param.param.value + " "
        elif tk_param.param.type == 'FILE':
          tk_param.param.value = tk_param.tk_var.get()
          if tk_param.param.value == "Browse...":
            tk_param.param.value = ""
          if tk_param.param.value != "":
            init_args = init_args + "-" + tk_param.param.name + " " + tk_param.param.value + " "
        elif tk_param.param.type == 'LOGIC':
          tk_param.param.value = tk_param.tk_var.get()
          if tk_param.param.value:
            init_args = init_args + "-" + tk_param.param.name + " "
      if plot_mode.get() != "pgplot":
        init_args = init_args + "-noplot"
      # Run Tao, clear the init_frame, and draw the main frame
      from tao_interface import tao_interface
      if chosen_interface.get() == "pexpect":
        mode = "pexpect"
        if tao_exe.tk_var.get() == "Browse...":
          tao_exe.tk_var.set("")
        self.pipe = tao_interface(mode, init_args, tao_exe.tk_var.get())
      elif chosen_interface.get() == "ctypes":
        if tao_lib.tk_var.get() == "Browse...":
          tao_lib.tk_var.set("")
        mode = "ctypes"
        self.pipe = tao_interface(mode, init_args, tao_lib.tk_var.get())

      init_frame.destroy()
      self.start_main()
      # Clear the plotting lists
      self.placed = {}
      self.plot_windows = []
      if plot_mode.get() == "matplotlib":
        self.pipe.cmd_in("set global force_plot_data_calc = T")
        # place the lattice layout in r1 by default
        self.pipe.cmd_in("place r1 lat_layout")
        self.pipe.cmd_in("set plot r1 visible = T")
        self.placed["lat_layout"] = 'r1'
      self.default_plots()

    # Font size
    tk.Label(init_frame, text="Font size").grid(row=k+3, sticky='E')
    font_var = tk.StringVar()
    if 'font_size' in init_dict.keys():
      font_var.set(str(init_dict['font_size']))
    else:
      font_var.set('14')
    font_box = tk.Entry(init_frame, textvariable=font_var)
    def update_font(event=None):
      try:
        new_size = int(font_var.get())
        new_font = font.nametofont("TkDefaultFont")
        new_font.configure(size=new_size)
        self.option_add("*Font", new_font)
      except:
        pass
      return 'break' # Don't load into Tao yet
    update_font() # Set the font for the first time
    font_box.bind('<Return>', update_font)
    font_box.grid(row=k+3, column=1, sticky='W')

    # Light-weight switch
    lw_var = tk.BooleanVar()
    if 'lw' in init_dict:
      lw_var.set((init_dict['lw']=='T') | (init_dict['lw'] == 'True'))
    else:
      lw_var.set(False)
    lw_box = tk.Checkbutton(init_frame, variable=lw_var)
    tk.Label(init_frame, text='Use lightweight interface?').grid(row=k+4, sticky='E')
    lw_box.grid(row=k+4, column=1, sticky='W')
    # Start button
    load_b = tk.Button(init_frame, text="Start Tao", command=param_load)
    load_b.grid(row=k+5, columnspan=2)
    self.bind_all("<Return>", param_load)

    #Start Tao immediately if skip_setup is set true
    if "skip_setup" in init_dict:
      if init_dict["skip_setup"] in ['T', 'True']:
        param_load()

  #-------------------------
  # Menu bar callbacks

  def read_cmd(self):
    print ('Read called')

  def write_cmd(self):
    print ('Write called')

  def reinit_cmd(self):
    '''
    Quit Tao, destroy the main frame, and respawn the init frame
    '''
    result = messagebox.askquestion("Reinit", "This will close all windows and restart Tao.  Are you sure?", icon="warning")
    if result != 'yes':
      return

    for child in root.winfo_children():
      child.destroy()

    self.pipe.cmd("quit")
    self.menubar_init()
    init_frame = tk.Frame(self)
    init_frame.pack()
    self.tao_load(init_frame)

  def quit_cmd(self, event = ''):
    result = messagebox.askquestion("Quit", "Are You Sure?", icon='warning')
    if result == 'yes':
      sys.exit(0)
    else:
      return

  def optimizer_cmd(self):
    print ('Optimizer called')
    win = tk.Toplevel(self)
    win.title('Optimizer')

  def plot_template_cmd(self):
    win = tao_plot_tr_window(self, self.pipe, "T")

  def plot_region_cmd(self):
    win = tao_plot_tr_window(self, self.pipe, "R")

  def wave_cmd(self):
    print ('Wave called')

  def set_global_vars_cmd(self):
    global_list = root.pipe.cmd_in("python global")
    global_list = global_list.splitlines()
    for i in range(len(global_list)):
      global_list[i]=str_to_tao_param(global_list[i])
    win = tao_parameter_window(self, "Global Variables", global_list, self.pipe)

    b = tk.Button(win.button_frame, text="Set Global Variables", command=lambda : tao_set(win.tao_list, "set global ", self.pipe))
    b.pack()

  def view_vars_cmd(self):
    win = tao_var_general_window(self, self.pipe)

  def view_data_cmd(self):
    win = tao_d2_data_window(self, self.pipe)

  def view_ele_cmd(self):
    win = tao_ele_window(self, self.pipe)

  def view_lattice_cmd(self):
    win = tao_lattice_window(self, self.pipe)

  # Other callbacks

  def global_vars_event(self, event):
    self.set_global_vars_cmd()

  def view_history_cmd(self):
    #Just focus the existing history window, if it exists
    try:
      self.history_window.lift()
      #self.history_window.force_focus()
    except:
      self.history_window = tao_history_window(root)

#-----------------------------------------------------

if __name__ == "__main__":
  root = tao_root_window(sys.argv)
  root.mainloop()
