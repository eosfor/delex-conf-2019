function Find-ASTItem {
    param(
        [string[]]$FullName,
        [ScriptBlock]$FindAll
    )

    Process {
        $Ast = [System.Management.Automation.Language.Parser]::ParseFile( (Resolve-Path $FullName) , [ref]$null, [ref]$null)

        foreach($item in $ast.FindAll($FindAll, $true)) {
            [PSCustomObject]@{
                FileName          = Split-Path -Leaf $item.Extent.File
                Name              = (ASTNameLookup $item.GetType().Name $Item)
                Line              = $item.Extent.Text
                StartLineNumber   = $item.Extent.StartLineNumber
                StartColumnNumber = $item.Extent.StartColumnNumber
                EndLineNumber     = $item.Extent.EndLineNumber
                EndColumnNumber   = $item.Extent.EndColumnNumber
                FullName          = $item.Extent.File
            }
        }
    }
}

function ASTNameLookup  {
    param($targetType)

    switch ($targetType) {

        AssignmentStatementAst  {$args[0].Left}
        ParameterAst            {$args[0].Name}
        CommandAst              {$args[0].CommandElements[0].Value}
        ForEachStatementAst     {"ForEach"}
        FunctionDefinitionAst   {$args[0].Name}

        default {$_}
    }
}

function Find-ASTItemByType {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname,
        $ASTType
    )

    Begin {
        $ASTType = "System.Management.Automation.Language.$($ASTType)" -as [Type]
    }

    Process {
        Find-ASTItem -FullName $Fullname -FindAll {

            param($ast)

            if($ast -is $ASTType) {
                $ast
            }
        } | Where Name -Match $Name
    }
}

function Find-VariableAssignment {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process { Find-ASTItemByType $Name $Fullname AssignmentStatementAst }
}

function Find-Function {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process { Find-ASTItemByType $Name $Fullname FunctionDefinitionAst }
}

function Find-Expression {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process { Find-ASTItemByType $Name $Fullname CommandAst }
}

function Find-Parameter {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process { Find-ASTItemByType $Name $Fullname ParameterAst }
}

$g = New-Graph -Type BidirectionalGraph
$f = dir "C:\Repo\Work\WKBG-BIF2\GBSTools\*.ps1" -Recurse | Find-Function
$f.name | % { Add-Vertex -Vertex $_ -Graph $g}



$f | % {
    $fName = $_.name
    $tmpFile = New-TemporaryFile
    $_.line >> ($tmpFile.fullname)
    $expr = Find-Expression -Fullname $tmpFile.fullname
    $expr.name | ? {$_} | ? {$_ -notin "%","where","?","select","out-null","sort","ft","fl","Write-Verbose" } | % { Add-Edge -From $fName -to $_ -Graph $g}
}

Show-GraphLayout -Graph $g
Export-Graph -Format Graphviz -Graph $g -Path C:\Temp\g.gv