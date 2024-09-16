#import module
Import-Module -Name 'FauxMyPosh'

#import configuration and cmdlet containing logic
# place in same directory as profile.ps1
. '.\FMPConfigExample.ps1.psm1'

# override Prompt() function in your profile.ps1  [see $PROFILE]
function Prompt(){
    # run cmdlet that handles outputing faux prompt to the cli
    Use-FauxPrompt
}