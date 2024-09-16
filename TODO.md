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

## Documentation

- [ ] Create README.md
- [ ] Create help
- [ ] Create more examples
- [ ] Create predefined themes for use

## GitParser
- [ ] add behind/ahead logic
