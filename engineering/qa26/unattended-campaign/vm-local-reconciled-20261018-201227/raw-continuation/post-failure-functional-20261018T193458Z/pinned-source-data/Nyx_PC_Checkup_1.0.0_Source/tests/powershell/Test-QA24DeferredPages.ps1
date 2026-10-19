param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major -ne 5){throw 'Native Windows PowerShell 5.1 is required.'}
if([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){throw 'STA is required.'}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::ThrowException)
$checks=New-Object 'Collections.Generic.List[object]'
$failure=$null
$hostForm=$null

function Assert-Case {
    param([string]$Name,[bool]$Condition)
    $checks.Add([pscustomobject]@{Name=$Name;Pass=$Condition})
    if(-not $Condition){throw "Assertion failed: $Name"}
}

function Get-CallbackHazards {
    param([string]$Text)
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseInput($Text,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ($errors.Message -join '; ')}
    $registrations=$ast.FindAll({param($node) $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $node.Member.Value -like 'Add_*'},$true)
    foreach($registration in $registrations){
        $owner=$registration.Parent
        while($null -ne $owner -and $owner -isnot [Management.Automation.Language.FunctionDefinitionAst]){$owner=$owner.Parent}
        $ownerName=if($null -eq $owner){'<script>'}else{$owner.Name}
        # These owners remain on the stack through Application.Run or ShowDialog.
        if($ownerName -in @('Show-NyxMainWindow','Show-NyxResultDetailDialog','Show-NyxReportPreviewDialog','Show-NyxUpdateAvailableDialog')){continue}
        foreach($argument in $registration.Arguments){
            if($argument -isnot [Management.Automation.Language.ScriptBlockExpressionAst]){
                if($ownerName -eq 'Show-NyxCategoryPage' -and $argument.Extent.Text -eq '$Action'){continue}
                "${ownerName}: nonliteral callback $($argument.Extent.Text)"
                continue
            }
            $bound=@{true=$true;false=$true;null=$true;'_'=$true;PSItem=$true;args=$true;this=$true}
            foreach($parameter in $argument.ScriptBlock.FindAll({param($node)$node -is [Management.Automation.Language.ParameterAst]},$true)){$bound[$parameter.Name.VariablePath.UserPath]=$true}
            foreach($assignment in $argument.ScriptBlock.FindAll({param($node)$node -is [Management.Automation.Language.AssignmentStatementAst]},$true)){
                if($assignment.Left -is [Management.Automation.Language.VariableExpressionAst]){$bound[$assignment.Left.VariablePath.UserPath]=$true}
            }
            foreach($loop in $argument.ScriptBlock.FindAll({param($node)$node -is [Management.Automation.Language.ForEachStatementAst]},$true)){$bound[$loop.Variable.VariablePath.UserPath]=$true}
            foreach($variable in $argument.ScriptBlock.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst]},$true)){
                $name=$variable.VariablePath.UserPath
                if($name -notmatch ':' -and -not $bound.ContainsKey($name)){"${ownerName}: unbound `$$name in $($registration.Member.Value)"}
            }
        }
    }
}

function Invoke-ControlEvent {
    param([Windows.Forms.Control]$Control,[string]$Method,[EventArgs]$EventArgs=[EventArgs]::Empty)
    $binding=[Reflection.BindingFlags]'Instance,NonPublic'
    $methodInfo=$Control.GetType().GetMethod($Method,$binding)
    if($null -eq $methodInfo){throw "Missing event method $Method"}
    $arguments=New-Object 'object[]' 1
    $arguments[0]=$EventArgs.PSObject.BaseObject
    [void]$methodInfo.Invoke($Control,$arguments)
}

try{
    $negative=@(Get-CallbackHazards 'function Bad { $search.Add_TextChanged({&$render $search.Text}) }')
    Assert-Case 'expired-local negative control detects render and search' ($negative.Count -eq 2)
    foreach($uiFile in Get-ChildItem -LiteralPath (Join-Path $AppRoot 'ui') -Filter '*.psm1'){
        $hazards=@(Get-CallbackHazards ([IO.File]::ReadAllText($uiFile.FullName)))
        Assert-Case ("deferred callback audit: {0}; {1}" -f $uiFile.Name,($hazards -join '; ')) ($hazards.Count -eq 0)
    }
    Import-Module (Join-Path $AppRoot 'ui\Theme.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $AppRoot 'ui\Controls.psm1') -Force -DisableNameChecking
    $module=Import-Module (Join-Path $AppRoot 'ui\MainWindow.psm1') -Force -DisableNameChecking -PassThru
    $hostForm=New-Object Windows.Forms.Form
    $hostForm.ClientSize=New-Object Drawing.Size(1100,720)
    $content=New-Object Windows.Forms.Panel
    $content.Dock='Fill'
    $hostForm.Controls.Add($content)
    $hostForm.Show()
    [Windows.Forms.Application]::DoEvents()
    & $module {
        param($Panel,$Root)
        $script:F021Opens=New-Object 'Collections.Generic.List[object]'
        $script:F021Messages=New-Object 'Collections.Generic.List[object]'
        function script:ConvertTo-NyxBytesText {param([int64]$Bytes) return "$Bytes B"}
        function script:Invoke-NyxOpen {param($Target,$Arguments) $script:F021Opens.Add([pscustomobject]@{Target=$Target;Arguments=$Arguments})}
        function script:Show-NyxPageMessage {
            param($Text,$Title='Nyx PC Checkup',$Buttons='OK',$Icon='None')
            $script:F021Messages.Add([pscustomobject]@{Text=$Text;Buttons=$Buttons})
            return [Windows.Forms.DialogResult]::No
        }
        function script:Invoke-NyxUiAction {throw 'Unexpected destructive execution in source regression'}
        $inventory=@(
            [pscustomobject]@{Name='Alpha Browser';Publisher='Acme Labs';Version='1';InstallDate='20260927';EstimatedSizeBytes=1024;InstallLocation=$Root},
            [pscustomobject]@{Name='Nyx Test';Publisher='Dietrich';Version='2';InstallDate='20260927';EstimatedSizeBytes=$null;InstallLocation=''},
            [pscustomobject]@{Name='Delta Tool';Publisher='Acme Labs';Version='3';InstallDate='20260927';EstimatedSizeBytes=2048;InstallLocation=(Join-Path $Root 'missing-f021-fixture')}
        )
        $candidates=@(
            [pscustomobject]@{Id='f021-a';Category='Temp';Name='A';AgeDays=3;SizeBytes=1024},
            [pscustomobject]@{Id='f021-b';Category='Temp';Name='B';AgeDays=4;SizeBytes=2048}
        )
        $script:NyxUi=@{
            Content=$Panel;Palette=(Get-NyxPalette 'Light');LayoutScale=1.0
            HeaderTitle=(New-Object Windows.Forms.Label);NavButtons=@();CurrentPage='Home'
            Scan=[pscustomobject]@{Results=@(
                [pscustomobject]@{CheckId='apps.inventory';Details=$inventory},
                [pscustomobject]@{CheckId='cleanup.preview';Details=[pscustomobject]@{Candidates=$candidates}}
            )}
        }
    } $content $AppRoot
    function Get-PageState {
        param([string]$Page)
        & $module {param($Name) Show-NyxPage -Page $Name} $Page
        $found=@($content.Controls | Where-Object {$_ -is [Windows.Forms.DataGridView]})
        if($found.Count -ne 1){throw "Expected one grid on $Page, found $($found.Count)"}
        return $found[0].Tag
    }
    for($cycle=1;$cycle -le 3;$cycle++){
        $state=Get-PageState Apps
        Assert-Case "Apps $cycle initial inventory" ($state.Grid.Rows.Count -eq 3)
        Assert-Case "Apps $cycle no selection disables folder" (-not $state.Folder.Enabled)
        foreach($filterCase in @(
            @('first character','n',1),@('multiple characters','Nyx',1),@('clear','',3),
            @('exact name','Alpha Browser',1),@('partial name','pha',1),@('publisher match','Dietrich',1),
            @('no-match','no_such_app_f021',0),@('literal regex','[',0),
            @('rapid 1','Al',1),@('rapid 2','Delta',1),@('rapid 3','Nyx',1),@('rapid 4','Acme',2),@('rapid clear','',3)
        )){
            $state.Search.Text=[string]$filterCase[1]
            Assert-Case "Apps $cycle $($filterCase[0])" ($state.Grid.Rows.Count -eq [int]$filterCase[2])
            Assert-Case "Apps $cycle $($filterCase[0]) resets selection" (-not $state.Folder.Enabled -and $state.Grid.SelectedRows.Count -eq 0)
        }
        $state.Search.Text='Alpha Browser'
        $state.Grid.CurrentCell=$state.Grid.Rows[0].Cells[0]
        $state.Grid.Rows[0].Selected=$true
        Assert-Case "Apps $cycle selection enables folder" $state.Folder.Enabled
        $state.Folder.PerformClick()
        $opened=& $module {$script:F021Opens[$script:F021Opens.Count-1]}
        Assert-Case "Apps $cycle valid folder target" ($opened.Target -eq 'explorer.exe' -and $opened.Arguments -eq ('"'+$AppRoot+'"'))
        $state.Search.Text='Nyx'
        Assert-Case "Apps $cycle filter clears stale selection" (-not $state.Folder.Enabled)
        $state.Grid.CurrentCell=$state.Grid.Rows[0].Cells[0]
        $state.Grid.Rows[0].Selected=$true
        $state.Folder.PerformClick()
        $message=& $module {$script:F021Messages[$script:F021Messages.Count-1]}
        Assert-Case "Apps $cycle unavailable folder message" ($message.Text -like 'No usable install folder*')
        $cleanupState=Get-PageState Cleanup
        Assert-Case "Apps $cycle disposed old page state" (-not $state.Active -and $state.Grid.IsDisposed)
        Invoke-ControlEvent $state.Search OnTextChanged
        Invoke-ControlEvent $state.Grid OnSelectionChanged
        Invoke-ControlEvent $state.Folder OnClick
        Assert-Case "Apps $cycle disposed callbacks safe" ($cleanupState.Active -and $cleanupState.Grid.Rows.Count -eq 2)
        $cleanupState.Grid.Rows[0].Cells[0].Value=$true
        Assert-Case "Cleanup $cycle CellValueChanged updates summary" ($cleanupState.Summary.Text -match '1' -and $cleanupState.Summary.Text -match '1024')
        $cleanupState.Grid.Rows[1].Cells[0].Value=$true
        Assert-Case "Cleanup $cycle both selected" ($cleanupState.Summary.Text -match '2' -and $cleanupState.Summary.Text -match '3072')
        Invoke-ControlEvent $cleanupState.Grid OnCurrentCellDirtyStateChanged
        $cleanupState.Run.PerformClick()
        $confirmation=& $module {$script:F021Messages[$script:F021Messages.Count-1]}
        Assert-Case "Cleanup $cycle confirmation retained and denied" ($confirmation.Buttons -eq 'YesNo')
        $cleanupState.Grid.Rows[0].Cells[0].Value=$false
        $cleanupState.Grid.Rows[1].Cells[0].Value=$false
        $cleanupState.Run.PerformClick()
        $emptyMessage=& $module {$script:F021Messages[$script:F021Messages.Count-1]}
        Assert-Case "Cleanup $cycle empty selection safe" ($emptyMessage.Text -eq 'Select at least one displayed item.')
        $nextState=Get-PageState Apps
        Assert-Case "Cleanup $cycle disposed state" (-not $cleanupState.Active)
        Invoke-ControlEvent $cleanupState.Grid OnCellValueChanged (New-Object Windows.Forms.DataGridViewCellEventArgs(-1,-1))
        Invoke-ControlEvent $cleanupState.Run OnClick
        $nextState.Search.Text='n'
        Assert-Case "Apps $cycle navigation back search works" ($nextState.Grid.Rows.Count -eq 1)
    }
}catch{
    $failure=$_.Exception.ToString()
    $checks.Add([pscustomobject]@{Name='unhandled source regression exception';Pass=$false;Detail=$failure})
}finally{
    if($null -ne $hostForm){$hostForm.Dispose()}
    $parent=Split-Path -Parent $OutputPath
    if($parent){[void][IO.Directory]::CreateDirectory($parent)}
    $passed=@($checks | Where-Object Pass).Count
    $failed=@($checks | Where-Object {-not $_.Pass}).Count
    [pscustomobject]@{
        Harness='QA26-F023-PS51-26';Kind='native source callback regression, not installed acceptance'
        PowerShell=$PSVersionTable.PSVersion.ToString();Passed=$passed;Failed=$failed
        ExternalBoundariesMocked=@('Explorer launch','message-box response: No','destructive action rejected','byte display format')
        Checks=$checks.ToArray();Exception=$failure
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Output "QA24 deferred pages: $passed PASS / $failed FAIL"
    if($failure){Write-Output $failure}
}
if($failed -gt 0){exit 1}
exit 0
