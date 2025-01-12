@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('core', 'Test-ScoopDebugEnabled')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "$($_[0]).ps1")
    }
}

function Invoke-GitCmd {
    <#
    .SYNOPSIS
        Git execution wrapper with -C parameter support.
    .PARAMETER Command
        Specifies git command to execute.
    .PARAMETER Repository
        Specifies fullpath to git repository.
    .PARAMETER Proxy
        Specifies the command needs proxy or not.
    .PARAMETER Argument
        Specifies additional arguments, which should be used.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('Cmd', 'Action')]
        [String] $Command,
        [String] $Repository,
        [Switch] $Proxy,
        [String[]] $Argument
    )

    begin {
        $preAction = @()
        if ($Repository) {
            $Repository = $Repository.TrimEnd('\').TrimEnd('/')
            $preAction = @('-C', """$Repository""")
        }
        $preAction += '--no-pager'
    }

    process {
        switch ($Command) {
            'CurrentCommit' {
                $action = 'rev-parse'
                $Argument = $Argument + @('HEAD')
            }
            'Update' {
                $action = 'pull'
                $Argument += '--rebase=false'
            }
            'UpdateLog' {
                $action = 'log'
                $para = @(
                    '--no-decorate'
                    '--format="tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset"'
                    '--regexp-ignore-case'
                    '--extended-regexp'
                    '--invert-grep'
                    '--grep="\[(scoop|shovel) skip\]"' # Ignore [scoop skip] [shovel skip]
                    '--grep="^Merge [pcb]"' # Ignore merge commits
                )
                $Argument = $para + $Argument
            }
            'VersionLog' {
                $action = 'log'
                $Argument += '--oneline', '--max-count=1', 'HEAD'
            }
            default { $action = $Command }
        }

        $commandToRun = $commandToRunNix = $commandToRunWindows = ('git', ($preAction -join ' '), $action, ($Argument -join ' ')) -join ' '

        if ($Proxy) {
            $prox = get_config 'proxy' 'none'

            if ($prox -and ($prox -ne 'none')) {
                $keyword = if (Test-IsUnix) { 'export' } else { 'SET' }
                $commandToRunWindows = $commandToRunNix = "$keyword HTTPS_PROXY=$prox&&$keyword HTTP_PROXY=$prox&&$commandToRun"
            }
        }

        Invoke-SystemComSpecCommand -Windows $commandToRunWindows -Unix $commandToRunNix
    }
}
