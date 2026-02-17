<#
.SYNOPSIS
Lists all SharePoint subsites under a site collection with their storage size.

.DESCRIPTION
Connects to a SharePoint site collection using PnP PowerShell and recursively
enumerates subsites. For each subsite, the script reads the CSOM Usage.Storage
value and prints a formatted report.

.PARAMETER SiteCollectionUrl
The URL of the site collection to scan (for example,
https://contoso.sharepoint.com/sites/Finance).

.PARAMETER IncludeRootWeb
When specified, includes the root web of the site collection in the output.

.PARAMETER CsvPath
Optional path to export the result to CSV.

.EXAMPLE
./List-SharePointSubsitesSize.ps1 -SiteCollectionUrl "https://contoso.sharepoint.com/sites/Finance" -IncludeRootWeb

.EXAMPLE
./List-SharePointSubsitesSize.ps1 -SiteCollectionUrl "https://contoso.sharepoint.com/sites/Finance" -CsvPath "./SubsiteSizes.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteCollectionUrl,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeRootWeb,

    [Parameter(Mandatory = $false)]
    [string]$CsvPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    throw "PnP.PowerShell module is not installed. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
}

function Convert-BytesToFriendlySize {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Bytes
    )

    if ($Bytes -lt 1KB) { return "{0:N0} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }

    return "{0:N2} TB" -f ($Bytes / 1TB)
}

function Get-WebUsageReport {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.SharePoint.Client.Web]$Web,

        [Parameter(Mandatory = $true)]
        [Microsoft.SharePoint.Client.ClientContext]$Context
    )

    $Context.Load($Web, `
        { $args[0].Title }, `
        { $args[0].Url }, `
        { $args[0].ServerRelativeUrl }, `
        { $args[0].Usage }, `
        { $args[0].Webs })
    $Context.ExecuteQuery()

    $bytes = 0.0
    if ($null -ne $Web.Usage -and $null -ne $Web.Usage.Storage) {
        $bytes = [double]$Web.Usage.Storage
    }

    $entry = [PSCustomObject]@{
        Title             = $Web.Title
        Url               = $Web.Url
        ServerRelativeUrl = $Web.ServerRelativeUrl
        SizeBytes         = [math]::Round($bytes, 0)
        SizeFriendly      = Convert-BytesToFriendlySize -Bytes $bytes
    }

    $result = New-Object System.Collections.Generic.List[object]
    $result.Add($entry) | Out-Null

    foreach ($childWeb in $Web.Webs) {
        $childItems = Get-WebUsageReport -Web $childWeb -Context $Context
        foreach ($child in $childItems) {
            $result.Add($child) | Out-Null
        }
    }

    return $result
}

Write-Host "Connecting to $SiteCollectionUrl ..." -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteCollectionUrl -Interactive

$ctx = Get-PnPContext
$rootWeb = Get-PnPWeb

$report = Get-WebUsageReport -Web $rootWeb -Context $ctx

if (-not $IncludeRootWeb.IsPresent) {
    $report = $report | Where-Object { $_.Url -ne $SiteCollectionUrl.TrimEnd('/') }
}

$sorted = $report | Sort-Object -Property SizeBytes -Descending

if (-not $sorted) {
    Write-Warning "No subsites found under $SiteCollectionUrl"
    return
}

$sorted | Format-Table -AutoSize Title, Url, SizeFriendly, SizeBytes

$totalBytes = ($sorted | Measure-Object -Property SizeBytes -Sum).Sum
Write-Host "`nSubsites found: $($sorted.Count)" -ForegroundColor Green
Write-Host "Total size: $(Convert-BytesToFriendlySize -Bytes $totalBytes) ($([math]::Round($totalBytes,0)) bytes)" -ForegroundColor Green

if ($CsvPath) {
    $sorted | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "CSV exported to: $CsvPath" -ForegroundColor Yellow
}
