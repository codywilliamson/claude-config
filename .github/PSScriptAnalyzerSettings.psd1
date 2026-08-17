@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # these files are standalone CLI scripts, not an exported module, so the
        # cmdlet naming conventions don't apply to their internal helpers
        'PSUseApprovedVerbs',
        'PSUseSingularNouns',

        # printing coloured status to a human is the entire job here. Write-Output
        # would put that text on the pipeline, which is worse, not better.
        'PSAvoidUsingWriteHost'
    )
}
