#import module
Import-Module -Name 'FauxMyPosh'

# DECLARE COLOR PALETTE
$White     = [FMPColor]::new("White")
$CoolWhite = [FMPColor]::new("AliceBlue")
$WarmWhite = [FMPColor]::new("FloralWhite")
$DimWhite  = [FMPColor]::new("Gainsboro")
$DarkGray  = [FMPColor]::new("DimGray")
$Green     = [FMPColor]::new("SeaGreen")
$Blue      = [FMPColor]::new("DodgerBlue")
$Orange    = [FMPColor]::new("Tomato")
$Purple    = [FMPColor]::new("MediumPurple")

# DECLARE THEMES
$usernameTheme       = [FMPColorTheme]::new($DarkGray,  $White)
$directoryTheme      = [FMPColorTheme]::new($CoolWhite, $Blue )
$dateTheme           = [FMPColorTheme]::new($WarmWhite, $Orange)
$timeTheme           = [FMPColorTheme]::new($DarkGray,  $White)
$gitGoodTheme        = [FMPColorTheme]::new($DimWhite,  $Green)
$gitNoRemoteTheme    = [FMPColorTheme]::new($DimWhite,  $Purple)
$gitHasUpdatesTheme  = [FMPColorTheme]::new($DimWhite,  $Orange)
$promptSymbolTheme   = [FMPColorTheme]::new()


# DECLARE FMPBLOCK CONFIGURATIONS
<#
    FMPBlocks are what handle the different sections of information you
    want displayed in your prompt

    $themedExampleConfig = @{
        text         = ''                   
        theme        = [FMPColorTheme]::new()
        textTemplate = $null
        refreshScript = $null
    }

    - Set 'text' if you're not going to be using a refreshscript
    - if setting 'refreshScript', text will be overwritten on update
    - 'refreshScript' must be a script that returns a string
    - theme is the color theme that will be used for the block (see #DECLARE THEMES above)
    - if no theme, block will write 'text' using system defaults for your cli
    - 'textTemplate' is that will wrap 'text' when written to the cli
      this is where you can add padding, special characters, etc
    - all can be overwritten later on based on logic if you need the 
      block to appear difference based on current states of the machine
#>

$themedUsernameConfig = @{
    text         = ("{0}@{1}" -f $env:USERNAME, $env:USERDOMAIN).ToLower()
    theme        = $usernameTheme
    textTemplate = '░░  {0} '
}


$themedDirectoryConfig = @{
    theme         = $directoryTheme
    textTemplate  = '|>  {0}  ░░'
    refreshScript = {
        $numDirToShow = 3
        $currPath     = (get-location).Path
        $splitPath    = $currPath.Split("\")
        
        if ($splitPath.Count -gt 3) {
            $bottomLevelParentDirs = $splitPath[($splitPath.Count - $numDirToShow)..$splitPath.Count]
            $currPath = @(
                "..."
                ($bottomLevelParentDirs -join "\")
                "  "
                ) -join ""
        }
        
        return $currPath
    }
}


$themedGitBadgeConfig = @{
    theme         = $gitGoodTheme
    textTemplate  = '  {0}  '
    refreshScript = {
        return [GitParser]::StatusToString()
    }
}


$themedDateConfig = @{
    theme         = $dateTheme
    textTemplate  = '░░ {0} '
    refreshScript = {
        return (Get-Date).ToString('dddd, MMMM d')
    }
}


$themedTimeConfig = @{
    theme        = $timeTheme
    textTemplate = ' {0} ░░'
    refreshScript = {
        return (Get-Date).ToString('h:mm tt')
    }
}


$themedPromptSymbolConfig = @{
    text  = 'PS> '
    theme = $promptSymbolTheme
}


# INITIALIZE PROMPT INFORMATION BLOCKS
$user         = New-FMPBlock @themedUsernameConfig
$location     = New-FMPBlock @themedDirectoryConfig
$date         = New-FMPBlock @themedDateConfig
$time         = New-FMPBlock @themedTimeConfig
$gitBadge     = New-FMPBlock @themedGitBadgeConfig
$promptSymbol = New-FMPBlock @themedPromptSymbolConfig


<# Below is a cmdlet that holds the logic for how the prompt should be written to the cli #>
function Use-FauxPrompt {
    param()

    Begin {        
        #update everything
        [GitParser]::Update()
        $user.update()
        $location.Update()
        $date.Update()
        $time.Update()
        $promptSymbol.Update()


        #changes based on environment
        if ($host.Name -notmatch 'ISE') {
            if ([GitParser]::hasUncommitedChanges) {
                $gitBadge.UpdateTheme($gitHasUpdatesTheme)
            }
            elseif (-not [GitParser]::remotebranch) {
                $gitBadge.UpdateTheme($gitNoRemoteTheme)
            } 
            else {
                $gitBadge.UpdateTheme($gitGoodTheme)
            }
        }
        else {
            $gitBadge.UpdateTextTemplate('| git:{0}')
            $user.UpdateTextTemplate('{0}')
        }


        # below numbers are used to calculate padding to right align date/time blocks
        $_linebuffer = $Host.UI.RawUI.BufferSize.Width
        $_textbuffer  = (@(
            $user.GetTemplatedText()
            $location.GetTemplatedText()
            $gitBadge.GetTemplatedText()
            $date.GetTemplatedText()
            $time.GetTemplatedText()
        ) -join "").Length

        # if not enough buffer to hold full prompt, shorten date string
        if(($_linebuffer - $_textbuffer) -lt 0){
            $oldDateLength = $date.GetTemplatedText().Length #caching value before udpate for diff
            $date.UpdateRefreshScript({return (Get-Date).ToString('MM/dd/yy')})
            $newDateLength = $date.GetTemplatedText().Length #for readability
            $_textbuffer -= $oldDateLength - $newDateLength #subtract difference in lengths after update from buffer
        }

        # if still not enough buffer, drop date altogether
        if(($_linebuffer - $_textbuffer) -lt 0){
            $_textbuffer -= $date.GetTemplatedText().Length
            $date.UpdateRefreshScript({return ''})
        }

        # if still not enough buffer, drop time as well
        # you're pushing your luck at this point
        if(($_linebuffer - $_textbuffer) -lt 0){
            $_textbuffer -= $time.GetTemplatedText().Length
            $time.UpdateRefreshScript({return ''})
        }

        # if still not enough buffer, drop username
        # at this point, if you break it, nothing will print...
        if(($_linebuffer - $_textbuffer) -lt 0){
            $_textbuffer -= $user.GetTemplatedText().Length
            $user.UpdateRefreshScript({''})
        }
    }

    Process {
        if ($host.Name -notmatch 'ISE') {
            $themedPrompt = (@(
                $user.GetThemedText()
                $location.GetThemedText()
                $gitBadge.GetThemedText()
                (' ' * ($_linebuffer - $_textbuffer))
                $date.GetThemedText()
                $time.GetThemedText()
                [System.Environment]::NewLine
                $promptSymbol.GetThemedText()
            ) | Where-Object {$_}) -join ""

            [FMPColorTheme]::WriteToConsole($themedPrompt)
        }
        else {
            @(
                $user.GetTemplatedText()
                " "
                $location.GetTemplatedText()
                $gitBadge.GetTemplatedText()
                (' ' * ($_linebuffer - $_textbuffer))
                $date.GetTemplatedText()
                $time.GetTemplatedText()
                [System.Environment]::NewLine
                $promptSymbol.GetTemplatedText()
            ) -join ""
        }
    }
}