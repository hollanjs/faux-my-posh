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
        return $this.theme.ConvertToThemedText($this.text)
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


class FMPColor {
    hidden [System.Drawing.Color] $_color = [System.Drawing.Color]::new()


    [bool] IsEmpty(){
        return $this._color.IsEmpty
    }


    [object] GetRGB () {
        return [PSCustomObject]@{
            Red   = $this._color.R
            Green = $this._color.G
            Blue  = $this._color.B
        }
    }


    [string] ToCliString () { 
        return ($this._color.R, $this._color.G, $this._color.B -join ';') 
    }
    

    [string] ToString () {
        return ('{0} [R={1}, G={2}, B={3}]' -f @(
            $this._color.Name
            $this._color.R
            $this._color.G
            $this._color.B
        ))
    }   


    [void] SetRed ([int32]$value){
        $this._color.R = $value
    }


    [void] SetGreen ([int32]$value){
        $this._color.G = $value
    }


    [void] SetBlue ([int32]$value){
        $this._color.B = $value
    }


    [void] SetToKnownColor ([System.Drawing.KnownColor]$knownColor){
        $this._color = [System.Drawing.Color]::FromKnownColor($knownColor)
    }


    [void] SetToRGB ([int32]$Red, [int32]$Green, [int32]$Blue){
        $this._color = [System.Drawing.Color]::FromArgb($Red, $Green, $Blue)
    }


    [void] SetToHex ([string]$hexColorCode){
        $this._color = [System.Drawing.ColorTranslator]::FromHtml($hexColorCode)
    }
    

    FMPColor(){
        # initialize as empty color object
    }
    

    FMPColor([int32]$Red, [int32]$Green, [int32]$Blue){
        $this._color = [System.Drawing.Color]::FromArgb($Red, $Green, $Blue)
    }
    

    FMPColor([string]$hexColorCode){
        $this._color = [System.Drawing.ColorTranslator]::FromHtml($hexColorCode)
    }
    

    FMPColor([System.Drawing.KnownColor]$knownColor){
        $this._color = [System.Drawing.Color]::FromKnownColor($knownColor)
    }
}


enum ColorLayer {
    foreground
    background
}


class FMPColorTheme {
    #To see available colors to use, go to:
    #    https://learn.microsoft.com/en-us/dotnet/api/system.windows.media.brushes?view=windowsdesktop-8.0
    
    hidden        [FMPColor] $foreground      = [FMPColor]::new()
    hidden        [FMPColor] $background      = [FMPColor]::new()
    hidden        [bool]     $isDisabled      = $false
    hidden static [char]     $CHAR_ESC        = [char]27
    hidden static [string]   $SEQ_ESCAPE      = 'ESCAPEME'
    hidden static [string]   $FORE_PREFIX     = @(38, 2) -join ";"
    hidden static [string]   $BACK_PREFIX     = @(48, 2) -join ";"
    hidden static [string]   $colorizePattern = "$([FMPColorTheme]::SEQ_ESCAPE)[{0};{1}m"
    hidden static [string]   $reset           = '{0}' -f ([FMPColorTheme]::colorizePattern -f $null, 0)
    hidden static [string]   $hardReset       = '{0}{0}' -f ([FMPColorTheme]::reset)
    
    
    static [string] CliColorReset (){
        return ([FMPColorTheme]::hardReset -replace [FMPColorTheme]::SEQ_ESCAPE, [FMPColorTheme]::CHAR_ESC)
    }
    

    static [string] WriteToConsole([FMPThemedText]$ThemedText){
        return ($ThemedText.GetThemedText() -replace [FMPColorTheme]::SEQ_ESCAPE, [FMPColorTheme]::CHAR_ESC)
    }
    

    [string] ToString() {
        return ('Foreground: {0}`nBackground: {1}' -f @(
            @{$true = 'Empty'; $false = $this.foreground}[$this.foreground.IsEmpty()]
            @{$true = 'Empty'; $false = $this.background}[$this.background.IsEmpty()]
        ))
    }
    

    [void] ColorReset ([ColorLayer]$layer){
        switch($layer){
            'foreground' { $this.foreground = [FMPColor]::new() }
            'background' { $this.background = [FMPColor]::new() }
        }
    }


    [void] DisableTheme () {
        $this.isDisabled = $true
    }


    [void] EnableTheme () {
        $this.isDisabled = $false
    }


    [string] ConvertToThemedText([string] $text){
        if($this.isDisabled){
            return (@(
                [FMPColorTheme]::hardReset,
                $text
            ) -join "")
        }

        if($this.foreground.IsEmpty() -and $this.background.IsEmpty()){
            return ([FMPColorTheme]::hardReset, $text -join "")
        }

        $foregroundCliString = $this.foreground.ToCliString()
        if($this.foreground.IsEmpty()){
            $foregroundCliString = [FMPColorTheme]::reset
        }
        
        $foregroundString = [FMPColorTheme]::colorizePattern -f @(
            [FMPColorTheme]::FORE_PREFIX, 
            $foregroundCliString
            )
            
            $backgroundCliString = $this.background.ToCliString()
            if($this.background.IsEmpty()){
                $backgroundCliString = [FMPColorTheme]::reset
            }
        $backgroundString = [FMPColorTheme]::colorizePattern -f @(
                                [FMPColorTheme]::BACK_PREFIX, 
                                $backgroundCliString
                            )

        return (@(
            $foregroundString, 
            $backgroundString,
            $text,
            [FMPColorTheme]::hardReset
        ) -join "")
    }
    

    FMPColorTheme(){
        # just use default initialization of empty foreground and background colors
    }


    FMPColorTheme([ColorLayer] $layer, [FMPColor] $color){
        switch($layer){
            'foreground' { $this.foreground = $color }
            'background' { $this.background = $color }
        }
    }
    

    FMPColorTheme([FMPColor] $ForegroundColor, [FMPColor] $BackgroundColor){
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
    hidden [bool]          $disableTheme        = $false
    hidden [scriptblock]   $defaultScriptBlock  = { if($this.text){ return $this.text } }
    hidden [string]        $defaultTextTemplate = '{0}'
    hidden [FMPColorTheme] $defaultTheme        = [FMPColorTheme]::New()

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