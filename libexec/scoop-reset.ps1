# Usage: scoop reset [<OPTIONS>] <APP>...
# Summary: Force binaries/shims, shortcuts, environment variables and persisted data to be re-linked.
# Help: Could be used to resolve conflicts in favor of a particular application(s).
# For example, if you have installed 'python' and 'python27', you can use 'scoop reset' to switch between
# using one or the other.
#
# When there are multiple installed versions of same application, they could be reset/switched also:
#    scoop reset bat@0.16.0 => shims will be relinked to use installed version 0.16.0 of application bat
#    scoop reset bat@0.17.0 => shims will be relinked to use installed version 0.17.0 of application bat
#
# 'scoop list' will show currently resetted/switched version.
#
# You can use '*' in place of <APP> to reset all installed applications.
#
# Options:
#   -h, --help      Show help for this command.

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'Resolve-GetOpt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('install', 'install_app'),
    @('manifest', 'Resolve-ManifestInformation'),
    @('shortcuts', 'rm_startmenu_shortcuts'),
    @('Versions', 'Clear-InstalledVersion')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")
    }
}

# TODO: Add --global

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop reset: $_err" -ExitCode 2 }
if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

if ($Applications -eq '*') {
    $Applications = @()
    foreach ($gl in $true, $false) {
        installed_apps $gl | ForEach-Object {
            $Applications += , @($_, $gl)
        }
    }
}

foreach ($a in $Applications) {
    ($app, $gl) = $a

    # TODO: Adopt Resolve-ManifestInformation ???
    # Only name and version is relevant, manual parse should be enough
    $app, $bucket, $version = parse_app $app

    # Skip scoop
    if ($app -eq 'scoop') { continue }

    if (!(installed $app)) {
        ++$Problems
        Write-UserMessage -Message "'$app' is not installed" -Err
        continue
    }

    # Set global flag when running reset command on specific app
    # TODO: This cannot be done automatically as user does not have admin rights most likely
    if (($null -eq $gl) -and (installed $app $true)) { $gl = $true }
    if ($null -eq $version) { $version = Select-CurrentVersion -AppName $app -Global:$gl }

    $manifest = installed_manifest $app $version $gl

    # When there is no manifest it is clear that application is not installed with this specific version
    if ($null -eq $manifest) {
        ++$Problems
        Write-UserMessage -Message "'$app ($version)' is not installed" -Err
        continue
    }

    if ($gl -and !(is_admin)) {
        Write-UserMessage -Message "'$app' ($version) is a installed globally. Admin privileges are required to reset it. Skipping" -Warning
        ++$Problems
        continue
    }

    Write-UserMessage -Message "Resetting $app ($version)"

    $dir = versiondir $app $version $gl | Resolve-Path
    $original_dir = $dir
    $persist_dir = persistdir $app $gl

    $install = install_info $app $version $gl
    $architecture = $install.architecture

    $dir = link_current $dir
    create_shims $manifest $dir $gl $architecture
    create_startmenu_shortcuts $manifest $dir $gl $architecture
    env_add_path $manifest $dir $gl $architecture
    env_set $manifest $dir $gl $architecture

    # Unlink all potential old link before re-persisting
    unlink_persist_data $original_dir
    persist_data $manifest $original_dir $persist_dir
    persist_permission $manifest $gl
}

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
