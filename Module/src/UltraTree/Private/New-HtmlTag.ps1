function New-HtmlTag {
    <#
    .SYNOPSIS
        Creates an inline tag/badge element.
    .DESCRIPTION
        Generates HTML for a small tag or badge with optional type styling.
    .PARAMETER Text
        The tag text content.
    .PARAMETER Type
        Optional type: empty string (default), "disabled", or "expired".
    #>
    param (
        [string]$Text,
        [ValidateSet("", "disabled", "expired")]
        [string]$Type = ""
    )
    $classExtra = if ($Type) { " $Type" } else { "" }
    "<div class=`"tag$classExtra`">$Text</div>"
}
