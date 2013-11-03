#!/usr/bin/env python

# To execute this file from within the Python interpreter:
#   execfile('this_file_name')

import sys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# Help

def print_help():
  print ('Usage:')
  print ('  det_pix_plot.py {-scale <scale>} {<data_file_name>}')
  print ('Defaults:')
  print ('  <scale>          = 1e3')
  print ('  <data_file_name> = lux.det_pix')
  exit() 

# Defaults

dat_file_name = 'lux.det_pix'

scale = 1e3

x_margin = 10
y_margin = 10

# Command line arguments

i = 1
while i < len(sys.argv):
  if sys.argv[i] == '-scale':
    scale = sys.argv[i+1]
    i += 1

  elif sys.argv[i][0] == '-':
    print_help()
    
  else:
    dat_file_name = sys.argv[i]

  i += 1

# Read data file parameters in header lines and data file data

dat_file = open (dat_file_name)

for n_header in range(1, 1000):
  line = dat_file.readline()
  if line[0:3] == '#--': break
  exec line

dat_file.close()

pix_dat = np.loadtxt(dat_file_name, usecols=(0,1,4), skiprows = n_header)

# Create density matrix

nx_min = nx_active_min - x_margin  # For border
nx_max = nx_active_max + x_margin
ny_min = ny_active_min - y_margin  # For border
ny_max = ny_active_max + y_margin

pix_mat = np.zeros((nx_max+1-nx_min, ny_max+1-ny_min))

for pix in pix_dat:
  pix_mat[pix[0]-nx_min,pix[1]-ny_min] = pix[2]

# And plot

x_min = scale * nx_min * dx_pixel
x_max = scale * nx_max * dx_pixel
y_min = scale * ny_min * dy_pixel
y_max = scale * ny_max * dy_pixel

if 'ix_plot' not in locals(): ix_plot = 0
ix_plot = ix_plot + 1

plt.set_cmap('gnuplot2_r')

fig = plt.figure(ix_plot)
ax = fig.add_subplot(111)

if x_max-x_min > y_max - y_min:
  it = max(1, int((y_max-y_min) * 8 / (x_max-x_min)))
  ax.yaxis.set_major_locator(ticker.MaxNLocator(it))
else:
  it = max(1, int((x_max-x_min) * 8 / (y_max-y_min)))
  ax.xaxis.set_major_locator(ticker.MaxNLocator(it))

dens = ax.imshow(np.transpose(pix_mat), origin = 'lower', extent = (x_min, x_max, y_min, y_max))

fig.colorbar(dens)

plt.show()
