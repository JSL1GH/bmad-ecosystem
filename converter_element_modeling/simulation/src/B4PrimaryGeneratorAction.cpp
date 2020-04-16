//
// ********************************************************************
// * License and Disclaimer                                           *
// *                                                                  *
// * The  Geant4 software  is  copyright of the Copyright Holders  of *
// * the Geant4 Collaboration.  It is provided  under  the terms  and *
// * conditions of the Geant4 Software License,  included in the file *
// * LICENSE and available at  http://cern.ch/geant4/license .  These *
// * include a list of copyright holders.                             *
// *                                                                  *
// * Neither the authors of this software system, nor their employing *
// * institutes,nor the agencies providing financial support for this *
// * work  make  any representation or  warranty, express or implied, *
// * regarding  this  software system or assume any liability for its *
// * use.  Please see the license in the file  LICENSE  and URL above *
// * for the full disclaimer and the limitation of liability.         *
// *                                                                  *
// * This  code  implementation is the result of  the  scientific and *
// * technical work of the GEANT4 collaboration.                      *
// * By using,  copying,  modifying or  distributing the software (or *
// * any work based  on the software)  you  agree  to acknowledge its *
// * use  in  resulting  scientific  publications,  and indicate your *
// * acceptance of all terms of the Geant4 Software license.          *
// ********************************************************************
//
// $Id: B4PrimaryGeneratorAction.cc 75215 2013-10-29 16:07:06Z gcosmo $
//
/// \file B4PrimaryGeneratorAction.cc
/// \brief Implementation of the B4PrimaryGeneratorAction class

#include "B4PrimaryGeneratorAction.hpp"

#include "G4RunManager.hh"
#include "G4LogicalVolumeStore.hh"
#include "G4LogicalVolume.hh"
#include "G4Box.hh"
#include "G4Event.hh"
#include "G4ParticleGun.hh"
#include "G4ParticleTable.hh"
#include "G4ParticleDefinition.hh"
#include "G4SystemOfUnits.hh"
#include "Randomize.hh"
#include <cmath>

//....oooOO0OOooo........oooOO0OOooo........oooOO0OOooo........oooOO0OOooo......

B4PrimaryGeneratorAction::B4PrimaryGeneratorAction(double in_particle_energy)
 : G4VUserPrimaryGeneratorAction(),
   fParticleGun(0)
{
  G4int nofParticles = 1;
  fParticleGun = new G4ParticleGun(nofParticles);

  //using namespace std;

  std::string in_particle_name = "e-";
  double in_particle_angle=0;
  //ifstream conf_file("config.txt", ios::in);
  //if ( conf_file.is_open() )
  //{
  //  //read txt file1
  //  while ( ! conf_file.eof() )
  //  {
  //    getline(conf_file, a_line);
  //    if(a_line.size()>0)
  //    {
  //      while (a_line.substr(0,1)==" ") a_line.erase(0,1);
  //      if(a_line.size()>15)
  //      {
  //        istringstream vars(a_line);
  //        if (a_line.substr(0,16)=="in_particle_name")  vars >> word[0] >> word[1] >> in_particle_name ;
  //        if (a_line.substr(0,18)=="in_particle_energy")  vars >> word[0] >> word[1] >> in_particle_energy;
  //        // added: read incoming angle from config.txt
  //        if (a_line.substr(0,17)=="in_particle_angle")  vars >> word[0] >> word[1] >> in_particle_angle;
  //      }
  //    }
  //  }
  //}
  //conf_file.close();

  // default particle kinematic
  //
  G4ParticleDefinition* particleDefinition
    = G4ParticleTable::GetParticleTable()->FindParticle(in_particle_name);
  fParticleGun->SetParticleDefinition(particleDefinition);
  // added: set particle angle off-axis
  fParticleGun->SetParticleMomentumDirection(
      G4ThreeVector(sin(in_particle_angle),0.,cos(in_particle_angle)));
  //fParticleGun->SetParticleMomentumDirection(G4ThreeVector(0.,0.,1.));
  fParticleGun->SetParticleEnergy(in_particle_energy*MeV);
}

//....oooOO0OOooo........oooOO0OOooo........oooOO0OOooo........oooOO0OOooo......

B4PrimaryGeneratorAction::~B4PrimaryGeneratorAction()
{
  delete fParticleGun;
}

//....oooOO0OOooo........oooOO0OOooo........oooOO0OOooo........oooOO0OOooo......

void B4PrimaryGeneratorAction::GeneratePrimaries(G4Event* anEvent)
{
  // This function is called at the begining of event

  // In order to avoid dependence of PrimaryGeneratorAction
  // on DetectorConstruction class we get world volume
  // from G4LogicalVolumeStore
  //
  G4double worldZHalfLength = 0;
  G4LogicalVolume* worlLV
    = G4LogicalVolumeStore::GetInstance()->GetVolume("World");
  G4Box* worldBox = 0;
  if ( worlLV) worldBox = dynamic_cast< G4Box*>(worlLV->GetSolid());
  if ( worldBox ) {
    worldZHalfLength = worldBox->GetZHalfLength();
  }
  else  {
    G4ExceptionDescription msg;
    msg << "World volume of box not found." << G4endl;
    msg << "Perhaps you have changed geometry." << G4endl;
    msg << "The gun will be place in the center.";
    G4Exception("B4PrimaryGeneratorAction::GeneratePrimaries()",
      "MyCode0002", JustWarning, msg);
  }

  // Set gun position
  fParticleGun
    ->SetParticlePosition(G4ThreeVector(0., 0., -worldZHalfLength));

  fParticleGun->GeneratePrimaryVertex(anEvent);
}

//....oooOO0OOooo........oooOO0OOooo........oooOO0OOooo........oooOO0OOooo......

