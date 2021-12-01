function Write-PSRAWFunctionFromTemplate
{

  [CmdletBinding()]
  param (

    [Parameter(Mandatory)]
    [String]
    $TemplatePath,

    [Parameter(Mandatory)]
    [String]
    $FunctionPrefix,

    [Parameter(Mandatory)]
    [String]
    $OutputPath,

    [String]
    $NoParams = 'NoParams',
    
    [String]
    $Ids = 'Ids',

    [Parameter(Mandatory)]
    [String]
    $PInvokeRestmethod,

    [Parameter(Mandatory)]
    [String]
    $PGetFunctionString,

    #[Parameter(Mandatory)]
    [array]
    $SwitchParams,

    [Parameter(Mandatory)]
    $OtherParams,

    [Parameter(Mandatory)]
    [String]
    $BaseUrl,

    [Parameter(Mandatory)]
    [String]
    $Tier1,

    [Parameter(Mandatory)]
    [String]
    $Tier2,

    [Parameter(Mandatory)]
    [String]
    $Method

  )
  
  begin
  {
    switch ($Method)
    {
      'Get'
      {
        $Verb = 'Get'
      }
      ('Patch' -or 'Put')
      {
        $Verb = 'Update'
      }
      'Delete'
      {
        $Verb = 'Remove'
      }
    }
    # Set noun Plural to Singular
    $Noun = ((Get-Culture).TextInfo.ToTitleCase($Tier2) -replace 's$', '' -replace 'sse$', 'ss')
    $FunctionName = '{0}-{1}{2}' -f $Verb, $FunctionPrefix, $Noun
  }
  
  process
  {
    $sread = [System.IO.StreamReader]::new($TemplatePath) 
    $FileContent = while ($sread.EndOfStream -eq $false)
    {
      $line = $sread.ReadLine()
      if ($line -match '^function')
      {
        $line -replace '__functionname__', $FunctionName
      }
      elseif ($line -match '\[CmdletBinding\(')
      {
        $line -replace '__noparams__', $NoParams
      }
      elseif ($line -match '<#__(?<RegionParam>\w+)__#>')
      {
        $RegionParam = $Matches.RegionParam
      }
      elseif ($RegionParam -eq 'ids')
      {
        if ($line -match '\[Parameter\(Mandatory')
        {
          if ($line -match '__ids__')
          {        
            $line -replace '__ids__', (Get-Culture).TextInfo.ToTitleCase($Ids)
          }
          elseif ($line -match '__switchparams__')
          {        
            $SwitchParams.ForEach{
              $line -replace '__switchparams__', (Get-Culture).TextInfo.ToTitleCase($_)
            }
          }
        }
        elseif ($line -match '\$__ids__')
        {
          $line -replace '__ids__', (Get-Culture).TextInfo.ToTitleCase($Ids)
        }
        elseif ($line -match ('<#end__ids__#>' -f $RegionParam))
        {
          $RegionParam = $null
        }
        else
        {
          $line
        }
      }
      elseif ($RegionParam -eq 'switchparams')
      {
        if ($SwitchParams)
        {
          if ($line -notmatch ('<#end__switchparams__#>' -f $RegionParam))
          {
            $LineColl += ('{0};' -f $line)
          }
          elseif ($line -match ('<#end__switchparams__#>' -f $RegionParam))
          {
            $SwitchParams.ForEach{
              $LineColl -split ';' -replace '__switchparams__', (Get-Culture).TextInfo.ToTitleCase($_)
            }
            $RegionParam = $null
            $LineColl = $null
            #$LineColl = ''
          }
        }
        else
        {
          if ($line -notmatch ('<#end__switchparams__#>' -f $RegionParam))
          {
          }
          elseif ($line -match ('<#end__switchparams__#>' -f $RegionParam))
          {
            $RegionParam = $null
          }
        }
      }
      elseif ($RegionParam -eq 'otherparams')
      {
        $i = 1
        if ($line -notmatch ('<#end__otherparams__#>' -f $RegionParam))
        {
          $LineColl += ('{0};' -f $line)
        }
        elseif ($line -match ('<#end__otherparams__#>' -f $RegionParam))
        {
          $OtherParams.GetEnumerator().ForEach{
            $OtherParam = $_
            $LineColl.Split(';' ).ForEach{
              $line = $_
              if ($line -match '__switchparams__')
              {
                $SwitchParams.GetEnumerator().ForEach{
                  $line -replace '__switchparams__', (Get-Culture).TextInfo.ToTitleCase($_)
                }
              }
              elseif ($line -match '__noparams__')
              {
                $line -replace '__noparams__', (Get-Culture).TextInfo.ToTitleCase($NoParams)
              }
              elseif ($line -match '__type__')
              {
                # [Integer] -> [Int]
                $Type = (Get-Culture).TextInfo.ToTitleCase($OtherParam.Type) -replace 'eger$', ''
                $line -replace '__type__', $Type
              }
              elseif (($line -match '__otherparams__') -and ($i -lt $OtherParams.Count))
              {
                $line -replace '__otherparams__', ('{0},' -f (Get-Culture).TextInfo.ToTitleCase($OtherParam.Name))
              }
              elseif ($line -match '__otherparams__')
              {
                $line -replace '__otherparams__', (Get-Culture).TextInfo.ToTitleCase($OtherParam.Name)
              }
            }
            # Empty Line
            if ($i -lt $OtherParams.Count)
            {
              Out-String
            }
            $i++
          }
          $RegionParam = $null
        }
      }
      elseif ($line -match '\$BaseUrl')
      {
        $line.replace(
          '__baseurl__', $BaseUrl
        ).replace(
          '__tier1__', $Tier1
        ).replace(
          '__tier2__', $Tier2
        )
      }
      elseif ($line -match '__ids__')
      {
        $line -replace '__Ids__', $Ids
      }
      elseif ($line -match '__noparams__')
      {
        $line -replace '__noparams__', $NoParams
      }
      elseif ($line -match '__method__')
      {
        $line -replace '__method__', $Method
      }
      elseif ($line -match '__pinvokerestmethod__')
      {
        $line -replace '__pinvokerestmethod__', $PInvokeRestmethod
      }
      elseif ($line -match '__pgetfunctionstring__')
      {
        $line -replace '__pgetfunctionstring__', $PGetFunctionString
      }
      else
      {
        $line
      }
    }
    $sread.close()

    # replace two or more blank with one and output file
    $blCtr = 0
    ($FileContent | Out-String -Stream).foreach{
      if (($_ -match '^$') -and ($blCtr -eq 0))
      {
        $blCtr++
        $_
      }
      elseif (($_ -match '^$') -and ($blCtr -gt 0))
      {
        $blCtr++
      }
      else
      {
        $blCtr = 0
        $_
      }
    } | Out-File -FilePath ('{0}\{1}.ps1' -f $OutputPath, $FunctionName) -Encoding UTF8
  }
  
  end
  {
  }
}