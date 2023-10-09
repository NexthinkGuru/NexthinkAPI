function Invoke-Workflow {
    <#
    .SYNOPSIS
        Triggers Automation Workflow
    .DESCRIPTION
        Triggers the execution of a Workflow for 1 or more devivces
    .INPUTS
        None.  Does not accept pipe objects
    .OUTPUTS
        System.string.  The requestUuid of the workflow automation instantiation
    .EXAMPLE
    PS> Invoke-Workflow -workflowId "#workflow_example" -devices @('<device_uuid_1>','<device_uuid_2>')
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('NqlID')]
        # The NQL ID of the Automation workflow.
        [string]$workflowId,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('DeviceIdList')]
        # An array of device collector UUID values
        [Array]$devices,
                      
        [parameter(Mandatory=$false)]
        # A key value hashtable of parameters for the automation
        [hashtable]$Parameters
    )
    $APITYPE = 'WF_Exec'
    
    $body = @{
        workflowId = $workflowId
        devices = $deviceIdList
    }

    # Build Add any optional dynamic parameters for the RA
    if (($null -ne $Parameters) -and ($Parameters.count -ge 1)) {
        $body.Add('params', $Parameters)
    }

    $bodyJson = $body | ConvertTo-Json -Depth 4

    Invoke-NxtApi -Type $APITYPE -Body $bodyJson -ReturnResponse
}
