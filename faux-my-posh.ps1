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
                return ('{0}  {1}' -f [GitParser]::localBranch, $statusBadges)
            }
            return ([GitParser]::localBranch)
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
    hidden [string]        $text
    hidden [FMPColorTheme] $theme
    
    [object] GetThemedText(){
        if($null -eq $this.text -or $this.text -eq ''){
            return $null
        }
        return $this.theme.GetThemedText($this.text)
    }

    [FMPColorTheme] GetTheme (){
        return $this.theme
    }

    [void] SetTheme([FMPColorTheme]$newTheme){
        $this.theme = $newTheme
    }

    [void] SetText([string]$text){
        $this.text = $text
    }

    hidden [void] Init([string]$text){
        $this.Init($text, [FMPColorTheme]::new())
        $this.theme.DisableTheme()
    }

    hidden [void] Init([FMPColorTheme]$theme){
        $this.Init('', $theme)
    }

    hidden [void] Init([string]$text, [FMPColorTheme]$theme){
        $this.text  = $text
        $this.theme = $theme
    }

    FMPThemedText([string]$text){
        $this.Init($text)
    }

    FMPThemedText([FMPColorTheme]$theme){
        $this.Init($theme)
    }
    
    FMPThemedText([string]$text, [FMPColorTheme]$theme){
        $this.Init($text, $theme)
    }
}

class FMPColorTheme {
    #To see available colors to use, go to:
    #    https://learn.microsoft.com/en-us/dotnet/api/system.windows.media.brushes?view=windowsdesktop-8.0
    #### turn reset into a single reset
    #### make hard reset a double reset
    #### set default colors to reset
    #### create enum for foreground and background 
    #### create constructor for enum to allow just foreground or background to be set
    #### verify replacing color with reset disables just that specific layer
    hidden [string] $foreground = $host.UI.RawUI.ForegroundColor
    hidden [string] $background = $host.UI.RawUI.BackgroundColor
    hidden [bool]   $isDisabled  = $false

    hidden static [char]   $CHAR_ESC   = [char]27
    hidden static [string] $SEQ_ESCAPE = "ESCAPEME"
    
    hidden static [string] $colorizePattern = "$([FMPColorTheme]::SEQ_ESCAPE)[{0};{1}m"
    
    hidden static [string] KnownColorToCliString([System.Drawing.KnownColor]$knownColor){
        $color = [System.Drawing.Color]::FromKnownColor($knownColor)
        return ($color.R, $color.G, $color.B -join ";")
    }
    
    hidden static [string] $resetString = '{0}{0}' -f ([FMPColorTheme]::colorizePattern -f $null, 0)

    static [string] WriteToConsole([string]$ThemedText){
        return ($ThemedText -replace [FMPColorTheme]::SEQ_ESCAPE, [FMPColorTheme]::CHAR_ESC)
    }

    [void] DisableTheme () {
        $this.isDisabled = $true
    }

    [void] EnableTheme () {
        $this.isDisabled = $false
    }

    [string] GetThemedText([string] $text){
        if($this.isDisabled){
            return (@(
                [FMPColorTheme]::resetString,
                $text
            ) -join "")
        }

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
    
    FMPColorTheme(){
        # just use default initialization of current foreground and background colors
    }

    FMPColorTheme([System.Drawing.KnownColor] $ForegroundColor){
        $this.foreground = $ForegroundColor
    }
    
    FMPColorTheme([System.Drawing.KnownColor] $ForegroundColor, [System.Drawing.KnownColor] $BackgroundColor){
        $this.foreground = $ForegroundColor
        $this.background = $BackgroundColor
    }
}


class FMPBlock {
    hidden [string]        $text
    hidden [FMPColorTheme] $theme
    hidden [FMPThemedText] $themedText
    hidden [string]        $templatedText
    hidden [string]        $textTemplate
    hidden [scriptblock]   $refreshScript

    hidden [bool]          $disableTheme = $false

    [void] Update () {
        $this.text = $this.refreshScript.Invoke()
        
        if($null -ne $this.text[0]){
            $this.templatedText = $this.textTemplate -f $this.text
            $this.themedText = [FMPThemedText]::new($this.templatedText, $this.theme)

            if(-not $this.themedText){
                [FMPThemedText]::new($this.text, $this.theme)
            }
            else{
                $this.themedText.SetTheme($this.theme)
            }
        }
    }

    [object] GetText(){
        if($null -eq $this.text -or $this.text -eq ''){
            return $null
        }
        return $this.text
    }

    [object] GetThemedText(){
        if($null -eq $this.text -or $this.text -eq ''){
            return $null
        }
        return $this.themedText.GetThemedText()
    }

    [object] GetTemplatedText(){
        if($null -eq $this.text -or $this.text -eq ''){
            return $null
        }
        return $this.templatedText
    }

    [void] UpdateText ([string]$text){
        $this.text = $text
        $this.Update()
    }

    [void] UpdateTheme ([FMPColorTheme]$theme){
        $this.theme = $theme
        $this.Update()
    }

    [void] UpdateTextTemplate ([string]$textTemplate){
        $this.textTemplate = $textTemplate
        $this.Update()
    }

    [void] UpdateRefreshScript ([scriptblock]$refreshScript){
        $this.refreshScript = $refreshScript
        $this.Update()
    }

    static [void] DisableTheme ([FMPBlock]$block) {
        $block.theme.DisableTheme.Invoke()
        $block.Update.Invoke()
    }

    static [void] EnableTheme ([FMPBlock]$block) {
        $block.theme.EnableTheme.Invoke()
        $block.Update.Invoke()
    }


    hidden [scriptblock]   $defaultScriptBlock  = { if($this.text){ return $this.text } }
    hidden [string]        $defaultTextTemplate = '{0}'
    hidden [FMPColorTheme] $defaultTheme        = [FMPColorTheme]::New()

    hidden Init ([string]$text) {
        $this.Init($text, $this.defaultTheme, $this.defaultTextTemplate, $this.defaultScriptBlock)
        [FMPBlock]::DisableTheme($this)
    }

    hidden Init ([string]$text, [FMPColorTheme]$theme) {
        $this.Init($text, $theme, $this.defaultTextTemplate, $this.defaultScriptBlock)
    }
    
    hidden Init ([string]$text, [FMPColorTheme]$theme, [string]$textTemplate) {
        $this.Init($text, $theme, $textTemplate, $this.defaultScriptBlock)
    }

    hidden Init ([string]$text, [FMPColorTheme]$theme, [scriptblock]$refreshScript) {
        $this.Init($text, $theme, $this.defaultTextTemplate, $refreshScript)
    }
    
    hidden Init ([string]$text, [FMPColorTheme]$theme, [string]$textTemplate, [scriptblock]$refreshScript) {
        $this.text = $text
        $this.theme = $theme
        $this.textTemplate = $textTemplate
        $this.refreshScript = $refreshScript

        # other values can count as valid, but break this class, so override if necessary
        if($null -eq $this.refreshScript -or $this.refreshScript.ast.Extent.Text -eq "{}"){
            $this.refreshScript = $this.defaultScriptBlock
        }

        if($this.textTemplate -eq ''){
            $this.textTemplate = $this.defaultTextTemplate
        }

        $this.Update()
    }

    FMPBlock ([string]$text){
        $this.Init($text)
    }

    FMPBlock ([string]$text, [FMPColorTheme]$theme){
        $this.Init($text, $theme)
    }

    FMPBlock ([string]$text, [FMPColorTheme]$theme, [scriptblock]$refreshScript){
        $this.Init($text, $theme, $refreshScript)
    }
    
    FMPBlock ([string]$text, [FMPColorTheme]$theme, [string]$textTemplate){
        $this.Init($text, $theme, $textTemplate)
    }

    FMPBlock ([string]$text, [FMPColorTheme]$theme, [string]$textTemplate, [scriptblock]$refreshScript){
        $this.Init($text, $theme, $textTemplate, $refreshScript)
    }
}

function New-FMPBlock {
    param
    (
        [Parameter()]    
        [string]
        $text = '', 


        [Parameter()]
        [FMPColorTheme]
        $theme, 


        [Parameter()]
        [string]
        $textTemplate, 


        [Parameter()]
        [scriptblock]
        $refreshScript
    )

    if($theme -and $textTemplate -and $refreshScript){
        return [FMPBlock]::new($text, $theme, $textTemplate, $refreshScript)
    }

    if($theme -and $textTemplate){
        return [FMPBlock]::new($text, $theme, $textTemplate)
    }

    if($theme-and $refreshScript){
        return [FMPBlock]::new($text, $theme, $refreshScript)
    }

    if($theme){
        return [FMPBlock]::new($text, $theme)
    }

    return [FMPBlock]::new($text)
}

# DECLARE THEMES
$usernameTheme       = [FMPColorTheme]::new("DimGray", "White")
$directoryTheme      = [FMPColorTheme]::new("AliceBlue", "DodgerBlue")
$dateTheme           = [FMPColorTheme]::new("FloralWhite", "Tomato")
$timeTheme           = [FMPColorTheme]::new("DimGray", "White")
$gitGoodTheme        = [FMPColorTheme]::new("Gainsboro", "SeaGreen")
$gitNoRemoteTheme    = [FMPColorTheme]::new("Gainsboro", "MediumPurple")
$gitHasUpdatesTheme  = [FMPColorTheme]::new("Gainsboro", "Tomato")

<#
    $themedExampleConfig = @{
        text         = ''
        theme        = [FMPColorTheme]::new()
        textTemplate = $null
        refreshScript = $null
    }
#>

$themedUsernameConfig = @{
    text         = ("{0}@{1}" -f $env:USERNAME, $env:USERDOMAIN).ToLower()
    theme        = $usernameTheme
    textTemplate = '    {0} '
}

$themedDirectoryConfig = @{
    theme        = $directoryTheme
    textTemplate = '|>  {0}  '
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
    theme        = $gitGoodTheme
    textTemplate = '| {0} '
    refreshScript = {
        return [GitParser]::StatusToString()
    }
}


$themedDateConfig = @{
    theme        = $dateTheme
    textTemplate = ' {0} '
    refreshScript = {
        return (Get-Date).ToString('dddd, MMMM d')
    }
}

$themedTimeConfig = @{
    theme        = $timeTheme
    textTemplate = ' {0} '
    refreshScript = {
        return (Get-Date).ToString('h:mm tt')
    }
}

$themedPromptSymbolConfig = @{
    text = 'PS> '
}


$user         = New-FMPBlock @themedUsernameConfig
$location     = New-FMPBlock @themedDirectoryConfig
$date         = New-FMPBlock @themedDateConfig
$time         = New-FMPBlock @themedTimeConfig
$gitBadge     = New-FMPBlock @themedGitBadgeConfig
$promptSymbol = New-FMPBlock @themedPromptSymbolConfig


function prompt {
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
