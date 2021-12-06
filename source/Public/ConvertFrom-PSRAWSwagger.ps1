function ConvertFrom-PSRAWSwagger
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    $Swagger,

    [Parameter(Mandatory)]
    [String]
    $FunctionNameVerb,

    [Parameter(Mandatory)]
    [String]
    $FunctionNamePrefix

  )

  begin
  {
    $TextInfo = (Get-Culture).TextInfo

  }

  process
  {
    $SwaggerColl = $Swagger | ConvertFrom-Json

    $EndPointColl = foreach ($item in $SwaggerColl.paths.PSObject.Properties)
    {
      [PSCustomObject]@{
        Name  = $item.Name
        Value = $item.Value
      }
    }

    $SplittedEndPointColl = ($EndPointColl.Name -split '/')

    $GroupedEndpointColl = ($SplittedEndPointColl.ForEach{
        $_
      }) | Group-Object | Sort-Object -Property Count -Descending #| Select-Object -ExpandProperty Name
    $MaxNumberGroupedEndpoint = ($GroupedEndpointColl | Select-Object -Property Count -First 1).Count

    $EqualMaxNumberGroupedEndpointColl = $GroupedEndpointColl | Where-Object {
    (($_ | Select-Object -Property Count).Count) -EQ $MaxNumberGroupedEndpoint
    } | Where-Object -Property Name | Select-Object -Property Name, Count

    $EndPoint0Splitted = ($EndPointColl.Name[0] -split '/')
    $i = 0
    while ($i -lt ($EndPoint0Splitted).Count)
    {
      if ($EndPoint0Splitted[$i] -in $EqualMaxNumberGroupedEndpointColl.Name )
      {
        $BaseURL = '{0}/{1}' -f $BaseURL, $EndPoint0Splitted[$i]
      }
      $i++
    }

    $PSGetEndPointColl = $EndPointColl | Where-Object { $null -ne $_.Value.get.parameters }
    $PSGetEndPointObjColl = foreach ($PSGetEndPoint in $PSGetEndPointColl)
    {
      $TierColl = $PSGetEndPoint.Name -replace ($BaseURL, '') -replace ('(\/{.*)', '')
      $Tier1 = ($TierColl -split '/')[1]
      $Tier2 = ($TierColl -split '/')[2]
      $FunctionNameNoun = Update-Text -Text $TextInfo.ToTitleCase($Tier2) -Replacements 'ies;y;s$;;ipaddresse;IPAdress'
      $FunctionName = '{0}-{1}{2}' -f $FunctionNameVerb, $FunctionNamePrefix, $FunctionNameNoun
      $Tags = $PSGetEndPoint.Value."$FunctionNameVerb".tags
      $Summary = $PSGetEndPoint.Value."$FunctionNameVerb".summary
      $Parameters = $PSGetEndPoint.Value."$FunctionNameVerb".parameters
      $Reponses = $PSGetEndPoint.Value."$FunctionNameVerb".responses
      [PSCustomObject]@{
        EndPoint         = $PSGetEndPoint.Name
        BaseUrl          = $BaseURL
        Tier1            = $Tier1
        Tier2            = $Tier2
        FunctionNameVerb = $FunctionNameVerb
        FunctionName     = $FunctionName
        Tags             = $Tags
        Summary          = $Summary
        Parameters       = $Parameters
        Reponses         = $Reponses
      }

    }

    $PSGetGroupedEndPointObjColl = ($PSGetEndPointObjColl |
        Group-Object -Property Tier1, Tier2 | Select-Object -Property Group).Group | ForEach-Object {

        [PSCustomObject]@{
          EndPoint         = $_.EndPoint
          BaseUrl          = $_.BaseUrl
          Tier1            = $_.Tier1
          Tier2            = $_.Tier2
          FunctionNameVerb = $_.FunctionNameVerb
          FunctionName     = $_.FunctionName
          Tags             = $_.Tags
          Summary          = $_.Summary
          Parameters       = $_.Parameters
          Reponses         = $_.Reponses
        }

      }

    $PSGetFunctionNameGroupedEndPointObjColl = $PSGetGroupedEndPointObjColl |
      Group-Object -Property FunctionName | ForEach-Object {

        $Tier1 = $_.Group[0].Tier1
        $Tier2 = $_.Group[0].Tier2

        $OtherParams = foreach ($Group in $_.Group[0])
        {
          $Group.Parameters
        }

        $SwitchParams = foreach ($Group in $_.Group)
        {
          if ($Group.Endpoint -match '.*{(?<IDParameter>\w.*)}$')
          {
            $Name = $Matches.IDParameter
          }
          elseif ($Group.Endpoint -match '.*{\w.*}\/(?<SwitchParameter>\w.*)$')
          {
            $Name = $Matches.SwitchParameter -replace ('/')
          }
          elseif ($Group.Endpoint -match ('^{0}\/{1}\/{2}$' -f $BaseUrl, $Tier1, $Tier2))
          {
            $Name = 'NoParams'
          }
          [PSCustomObject]@{
            Name    = $Name
            Summary = $Group.Summary
          }
        }

        [PSCustomObject]@{
          FunctionName     = $_.Name
          OtherParams      = $OtherParams
          SwitchParams     = $SwitchParams
          FunctionNameVerb = $_.Group[0].FunctionNameVerb
          BaseUrl          = $BaseUrl
          Tier1            = $_.Group[0].Tier1
          Tier2            = $_.Group[0].Tier2
        }
      }

    $PSGetFunctionNameGroupedEndPointObjColl
  }

  end
  {
  }
}