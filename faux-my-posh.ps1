#Drop into any $profile.ps1

Add-Type -Assembly System.Drawing

class GitParser {
    static [string]   $localBranch
    static [string]   $remoteBranch
    static [string]   $gitPath
    static [string[]] $status
    static [int32]    $numUntracked
    static [int32]    $numTracked
    static [int32]    $numModified
    static [bool]     $showBadge
    static [bool]     $hasUncommitedChanges

    static [bool] IsGitEnabled(){
        git rev-parse 2>$null
        return $?
    }

    static [object] StatusToString(){
        $statusBadges = $null
        
        if([GitParser]::showBadge){
            $statusBadges = (@(
                @{ $true = '*{0}' -f [GitParser]::numModified;  $false = '' }[[GitParser]::numModified  -gt 0]
                @{ $true = '+{0}' -f [GitParser]::numTracked;   $false = '' }[[GitParser]::numTracked   -gt 0]
                @{ $true = '?{0}' -f [GitParser]::numUntracked; $false = '' }[[GitParser]::numUntracked -gt 0]
                @{ $true = ''; $false = 'No Remote!' }[[GitParser]::remoteBranch -eq [GitParser]::localBranch]
            ) -join ", " -replace "(,\s*)+", ", ").Trim(", ") | Where-Object {$_} #only if exists
            if($statusBadges.Count -gt 0){
                $statusBadges = '>> {0} <' -f $statusBadges
                return ('| {0}  {1}' -f [GitParser]::localBranch, $statusBadges)
            }
            return ('| {0}  ' -f [GitParser]::localBranch)
        }
        return $null
    }

    static [void] CheckRemote (){
        if (-not [GitParser]::remoteBranch -or [GitParser]::remoteBranch -ne [GitParser]::localBranch) {
            [GitParser]::remoteBranch = $_branches = $_branch = $null

            $_branches = git branch -a 
            if($_branches){
                $_branch = $_branches | Where-Object { 
                    $_ -match (".{2}remotes.*$([GitParser]::localBranch)")
                }
            }

            if ($_branch) {
                [GitParser]::remoteBranch = $_branch.Split("/")[-1]
            }
        }
    }

    static [void] Update(){
        [GitParser]::showBadge = [GitParser]::IsGitEnabled()

        if([GitParser]::showBadge){
            [GitParser]::localBranch  = git branch --show-current
            [GitParser]::status       = git status --porcelain
            [GitParser]::numModified  = ([GitParser]::status | Where-Object { $_ -match '^\s?M'  }).Count
            [GitParser]::numTracked   = ([GitParser]::status | Where-Object { $_ -match '^\s?A'  }).Count
            [GitParser]::numUntracked = ([GitParser]::status | Where-Object { $_ -match '^\?+' }).Count
            
            [GitParser]::hasUncommitedChanges = $false
            if(([GitParser]::numModified + [GitParser]::numTracked + [GitParser]::numUntracked) -gt 0){
                [GitParser]::hasUncommitedChanges = $true
            }

            [GitParser]::CheckRemote()
        }
    }
}


class FMPThemedText{
    [string]        $text
    [FMPColorTheme] $theme
    
    [object] GetThemedText(){
        if($null -eq $this.text){
            return $null
        }
        return $this.theme.GetThemedText($this.text)
    }

    [void] WriteToConsole(){
        #figure out better way to write from themed text class
        #return value string
    }

    [void] SetTheme([FMPColorTheme]$newTheme){
        $this.theme = $newTheme
    }

    [void] SetText([string]$text){
        $this.text = $text
    }

    FMPThemedText([FMPColorTheme]$theme){
        $this.theme = $theme
    }
    
    FMPThemedText([string]$text, [FMPColorTheme]$theme){
        $this.text  = $text
        $this.theme = $theme
    }
}

class FMPColorTheme {
    #To see available colors to use, go to:
    #    https://learn.microsoft.com/en-us/dotnet/api/system.windows.media.brushes?view=windowsdesktop-8.0
    [string] $foreground = $host.UI.RawUI.ForegroundColor
    [string] $background = $host.UI.RawUI.BackgroundColor

    static [char]   $CHAR_ESC   = [char]27
    static [string] $SEQ_ESCAPE = "ESCAPEME"
    
    static [string] $colorizePattern = "$([FMPColorTheme]::SEQ_ESCAPE)[{0};{1}m"
    
    static [string] KnownColorToCliString([System.Drawing.KnownColor]$knownColor){
        $color = [System.Drawing.Color]::FromKnownColor($knownColor)
        return ($color.R, $color.G, $color.B -join ";")
    }
    
    static [string] $resetString = '{0}{0}' -f ([FMPColorTheme]::colorizePattern -f $null, 0)

    static [string] WriteToConsole([string]$ThemedText){
        return ($ThemedText -replace [FMPColorTheme]::SEQ_ESCAPE, [FMPColorTheme]::CHAR_ESC)
    }

    [string] GetThemedText([string] $text){
        $prefixForeground = @(38, 2) -join ";"
        $prefixBackground = @(48, 2) -join ";"

        $cliForeground = [FMPColorTheme]::KnownColorToCliString($this.foreground)
        $cliBackground = [FMPColorTheme]::KnownColorToCliString($this.background)

        $foregroundString = [FMPColorTheme]::colorizePattern -f $prefixForeground, $cliForeground
        $backgroundString = [FMPColorTheme]::colorizePattern -f $prefixBackground, $cliBackground

        return (@(
            $foregroundString, 
            $backgroundString,
            $text,
            [FMPColorTheme]::resetString
        ) -join "")
    }
    
    FMPColorTheme([System.Drawing.KnownColor] $ForegroundColor){
        $this.foreground = $ForegroundColor
    }
    
    FMPColorTheme([System.Drawing.KnownColor] $ForegroundColor, [System.Drawing.KnownColor] $BackgroundColor){
        $this.foreground = $ForegroundColor
        $this.background = $BackgroundColor
    }
}


# THEME SETUP
$usernameTheme       = [FMPColorTheme]::new("DimGray", "White")
$directoryTheme      = [FMPColorTheme]::new("AliceBlue", "DodgerBlue")
$dateTheme           = [FMPColorTheme]::new("FloralWhite", "Tomato")
$timeTheme           = [FMPColorTheme]::new("DimGray", "White")
$gitGoodTheme        = [FMPColorTheme]::new("Gainsboro", "SeaGreen")
$gitNoRemoteTheme    = [FMPColorTheme]::new("Gainsboro", "MediumPurple")
$gitHasUpdatesTheme  = [FMPColorTheme]::new("Gainsboro", "Tomato")

function prompt {
    param()

    Begin {
        <############################  information gathering/setup  #############################>
        $user = ("    {0}@{1} " -f $env:USERNAME, $env:USERDOMAIN).ToLower()

        $numDirToShow = 3
        $splitPath = (get-location).Path.Split("\")
        if ($splitPath.Count -gt 3) {
            $bottomLevelParentDirs = $splitPath[($splitPath.Count - $numDirToShow)..$splitPath.Count]
            $location = (, "|> ..." + $bottomLevelParentDirs) -join "\"
            $location += "  "
        }
        else {
            $location = "|>  {0}  " -f (get-location).Path
        }

        [GitParser]::Update()
        $gitBadge = [GitParser]::StatusToString()
        
        $promptSymbol = "PS> "

        $datetime = Get-Date
        $dateString = $datetime.ToString(' dddd, MMMM d ')
        $timeString = $datetime.ToString(' h:mm tt ')

        # below numbers are used to calculate padding to right align date/time blocks
        $_linebuffer = $Host.UI.RawUI.BufferSize.Width
        $_textbuffer  = (@(
            $user
            $location
            $gitBadge
            $dateString
            $timeString
        ) -join "").Length
        <########################################################################################>


        <####################################  Theme setup  #####################################>
        $themedUser      = [FMPThemedText]::new($user, $usernameTheme)
        $themedDirectory = [FMPThemedText]::new($location, $directoryTheme)    
        $themedDate      = [FMPThemedText]::new($dateString, $dateTheme)
        $themedTime      = [FMPThemedText]::new($timeString, $timeTheme)    
        $themedGitBadge  = [FMPThemedText]::new($gitGoodTheme)

        if ($host.Name -notmatch 'ISE') {
            if ([GitParser]::hasUncommitedChanges) {
                $themedGitBadge.SetText($gitBadge)
                $themedGitBadge.SetTheme($gitHasUpdatesTheme)
            }
            elseif (-not [GitParser]::remotebranch) {
                $themedGitBadge.SetText($gitBadge)
                $themedGitBadge.SetTheme($gitNoRemoteTheme)
            }
            else {
                $themedGitBadge.SetText($gitBadge)
            }
        }
        <########################################################################################>
    }

    Process {
        # if not enough buffer to hold full prompt, shorten date string
        if(($_linebuffer - $_textbuffer) -lt 0){
            $shortDateString = $datetime.ToString(' MM/dd/yy ')
            $themedDate.SetText($shortDateString)
            $_textbuffer -= $dateString.Length - $shortDateString.Length
        }

        # if still not enough buffer, drop date altogether
        if(($_linebuffer - $_textbuffer) -lt 0){
            $themedDate.SetText($null)
            $_textbuffer -= $shortDateString.Length
        }

        # if still not enough buffer, drop time as well
        # you're pushing your luck at this point
        if(($_linebuffer - $_textbuffer) -lt 0){
            $themedTime.SetText($null)
            $_textbuffer -= $timeString.Length
        }

        # if still not enough buffer, drop username
        # at this point, if you break it, nothing will print...
        if(($_linebuffer - $_textbuffer) -lt 0){
            $themedUser.SetText($null)
            $_textbuffer -= $user.Length
        }

        if ($host.Name -notmatch 'ISE') {
            $themedPrompt = (@(
                $themedUser.GetThemedText()
                $themedDirectory.GetThemedText()
                $themedGitBadge.GetThemedText()
                (' ' * ($_linebuffer - $_textbuffer))
                $themedDate.GetThemedText()
                $themedTime.GetThemedText()
                [System.Environment]::NewLine
                $promptSymbol 
            ) | Where-Object {$_}) -join ""

            [FMPColorTheme]::WriteToConsole($themedPrompt)
        }
        else {
            if($null -ne $gitBadge){
                $gitBadge = $gitBadge.Replace("| ", "| git:")
            }

            @(
                $user.Trim(" ")
                " "
                $location
                $gitBadge
                (' ' * ($_linebuffer - $_textbuffer))
                $dateString
                $timeString
                [System.Environment]::NewLine
                $promptSymbol
            ) -join ""
        }
    }
}