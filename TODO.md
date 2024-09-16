# TO DO

## Setup

- [ ] Create module manifest
- [ ] turn into module
- [ ] create pipeline to push to artifacts

## functionality

- [ ] make class that handles 'packing' fmpblocks into prompt
- [ ] class should pack into lines
- [ ] should provide interface to set row and heirarchy for packing
- [ ] should allow for multiple rows for fmpblocks per prompt
- [ ] should allow right and left alignment with empty between
- [ ] class should also have method to chain call updates of fmpblocks  
- [ ] implement some sort of basic fallback functionality for multiple refresh script
  - [ ] refresh scripts should have heirarchy
  - [ ] fallbacks should check fmpblock if important
    - [ ] if fmpblock not important, and there are no more fallback refreshscripts, remove block based on heirarchy as cli width becomes increasingly smaller
       
- [ ] create serialization functionality that exports prompt configurations to xml file
- [ ] create deserialization functionality to import xml files
- [ ] create a DEFAULT configuration that users can import via `Import-DefaultFMPConfiguration`
  - [ ] Users should be able to update the default theme from there if they want and override funcationlity or colors

## Documentation

- [ ] Create README.md
- [ ] Create help
- [ ] Create more examples
- [ ] Create predefined themes for use

## GitParser
- [ ] add behind/ahead logic

## Classes

- [ ] break apart classes into individual files in a subfolder called classes
- [ ] import all classes in via root psm1 file

##  Cmdlets
- [ ] move cmdlets into public and private folders
- [ ] import all public and private classes via root psm1 file

## PSD

- [ ] expose only classes and public functions
