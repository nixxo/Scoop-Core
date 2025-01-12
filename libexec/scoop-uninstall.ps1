# Usage: scoop uninstall [<OPTIONS>] <APP>...
# Summary: Uninstall specified application(s).
#
# Options:
#   -h, --help     Show help for this command.
#   -g, --global   Uninstall a globally installed application(s).
#   -p, --purge    Persisted data will be removed.
#                  Normally when application is being uninstalled, the data defined in persist property/manually persisted are kept.

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'Resolve-GetOpt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('install', 'install_app'),
    @('Applications', 'Get-InstalledApplicationInformation'),
    @('manifest', 'Resolve-ManifestInformation'),
    @('psmodules', 'install_psmodule'),
    @('shortcuts', 'rm_startmenu_shortcuts'),
    @('Uninstall', 'Uninstall-ScoopApplication'),
    @('Versions', 'Clear-InstalledVersion')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")
    }
}

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = Resolve-GetOpt $args 'gp' 'global', 'purge'

if ($_err) { Stop-ScoopExecution -Message "scoop uninstall: $_err" -ExitCode 2 }

$Global = $Options.g -or $Options.global
$Purge = $Options.p -or $Options.purge

if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }
if ($Global -and !(is_admin)) { Stop-ScoopExecution -Message 'Administrator privileges are required to uninstall globally installed applications.' -ExitCode 4 }

if ($Applications -eq 'scoop') {
    & (Join-Path $PSScriptRoot '..\bin\uninstall.ps1') $Global $Purge
    exit $LASTEXITCODE
}

$Applications = Confirm-InstallationStatus $Applications -Global:$Global

# This is not strict error
# Keeping it with zero exit code will allow chaining of commands in such use case (mainly vscode tasks dependencies)
if (!$Applications) { Stop-ScoopExecution -Message 'No application to uninstall' -ExitCode 0 -SkipSeverity }

foreach ($explode in $Applications) {
    ($app, $gl, $bucket) = $explode
    $result = $false

    try {
        $result = Uninstall-ScoopApplication -App $app -Global:$gl -Purge:$Purge -Older
    } catch {
        ++$Problems
        debug $_.InvocationInfo
        New-IssuePromptFromException -ExceptionMessage $_.Exception.Message -Application $app -Bucket $bucket

        continue
    }

    if ($result -eq $false) {
        ++$Problems
        continue
    }

    Write-UserMessage -Message "'$app' was uninstalled" -Success
}

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
