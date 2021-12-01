#
#    DATE: 02 Nov 2021
#    UPDATED: 1 Dec 2021
#    
#    MIT License
#    Copyright (c) 2021 Austin Livengood
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
#

# CHANGABLE VARIABLES
$sitePath = "https://usaf.dps.mil/sites/52msg/cs/" # SITE PATH
$parentSiteOnly = $false # SEARCH ONLY PARENT SITE AND IGNORE SUB SITES
$reportPath = "C:\users\$env:USERNAME\Desktop\$((Get-Date).ToString("yyyyMMdd_HHmmss"))_SitePIIResults.csv" # REPORT PATH (DEFAULT IS TO DESKTOP)
$results = @() # RESULTS
$dirtyWords = @("\d{3}-\d{3}-\d{4}","\d{3}-\d{2}-\d{4}","MyFitness","CUI","UPMR","SURF","PA","2583","SF86","SF 86","FOUO","GTC","medical","AF469","AF 469","469","Visitor Request","VisitorRequest","Visitor","eQIP","EPR","910","AF910","AF 910","911","AF911","AF 911","OPR","eval","feedback","loc","loa","lor","alpha roster","alpha","roster","recall","SSN","SSAN","AF1466","1466","AF 1466","AF1566","AF 1566","1566","SGLV","SF182","182","SF 182","allocation notice","credit","allocation","2583","AF 1466","AF1466","1466","AF1566","AF 1566","1566","AF469","AF 469","469","AF 422","AF422","422","AF910","AF 910","910","AF911","AF 911","911","AF77","AF 77","77","AF475","AF 475","475","AF707","AF 707","707","AF709","AF 709","709","AF 724","AF724","724","AF912","AF 912","912","AF 931","AF931","931","AF932","AF 932","932","AF948","AF 948","948","AF 3538","AF3538","3538","AF3538E","AF 3538E","AF2096","AF 2096","2096","AF 2098","AF2098","AF 2098","AF 3538","AF3538","3538","1466","1566","469","422","travel","SF128","SF 128","128","SF 86","SF86","86","SGLV","SGLI","DD214","DD 214","214","DD 149","DD149","149")

Connect-PnPOnline -Url $sitePath -UseWebLogin # CONNECT TO SPO
$subSites = Get-PnPSubWeb -Recurse # GET ALL SUBSITES
$getDocLibs = Get-PnPList | Where-Object {$_.BaseTemplate -eq 101}

Write-Host "Searching: $($sitePath)" -ForegroundColor Green

# GET PARENT DOCUMENT LIBRARIES
foreach ($DocLib in $getDocLibs) {
    $allItems = Get-PnPListItem -List $DocLib -Fields "FileRef", "File_x0020_Type", "FileLeafRef", "File_x0020_Size", "Created", "Modified" 
   
    #LOOP THROUGH EACH DOCMENT IN THE PARENT SITES
    foreach ($Item in $allItems) {
        foreach ($word in $dirtyWords) {
            $wordSearch = "(?i)\b$($word)\b"

            if (($Item["FileLeafRef"] -match $wordSearch)) {
                Write-Host "File found. " -ForegroundColor Red -nonewline; Write-Host "Under: '$($word)' Path: $($Item["FileRef"])" -ForegroundColor Yellow;

                $permissions = @()
                $perm = Get-PnPProperty -ClientObject $Item -Property RoleAssignments       
                foreach ($role in $Item.RoleAssignments) {
                    $loginName = Get-PnPProperty -ClientObject $role.Member -Property LoginName
                    $rolebindings = Get-PnPProperty -ClientObject $role -Property RoleDefinitionBindings
                    $permissions += "$($loginName) - $($rolebindings.Name)"
                    # Write-Host "$($loginName) - $($rolebindings.Name)" -ForegroundColor Yellow
                }
                $permissions = $permissions | Out-String
           
                $results = New-Object PSObject -Property @{
                    FileName = $subItem["FileLeafRef"]
                    FileExtension = $subItem["File_x0020_Type"]
                    FileSize = $subItem["File_x0020_Size"]
                    Path = $subItem["FileRef"]
                    Permissions = $permissions
                    Criteria = $word
                    Created = $subItem["Created"]
                    Modified = $subItem["Modified"]
                }

                if (test-path $reportPath) {
                    $results | Select-Object "FileName", "FileExtension", "FileSize", "Path", "Permissions", "Criteria", "Created", "Modified" | Export-Csv -Path $reportPath -Force -NoTypeInformation -Append
                } else {
                    $results | Select-Object "FileName", "FileExtension", "FileSize", "Path", "Permissions", "Criteria", "Created", "Modified" | Export-Csv -Path $reportPath -Force -NoTypeInformation
                }
            }
        }
    }
}

if ($parentSiteOnly -eq $false) {
    # GET ALL SUB SITE DOCUMENT LIBRARIES
    foreach ($site in $subSites) {
        Connect-PnPOnline -Url $site.Url -UseWebLogin # CONNECT TO SPO SUBSITE
        $getSubDocLibs = Get-PnPList | Where-Object {$_.BaseTemplate -eq 101}

        Write-Host "Searching: $($site.Url)" -ForegroundColor Green

        foreach ($subDocLib in $getSubDocLibs) {
            $allSubItems = Get-PnPListItem -List $subDocLib -Fields "FileRef", "File_x0020_Type", "FileLeafRef", "File_x0020_Size", "Created", "Modified" 
   
            #LOOP THROUGH EACH DOCMENT IN THE SUB SITES
            foreach ($subItem in $allSubItems) {
                foreach ($word in $dirtyWords) {
                    $wordSearch = "(?i)\b$($word)\b"

                    if (($subItem["FileLeafRef"] -match $wordSearch)) {
                        Write-Host "File found. " -ForegroundColor Red -nonewline; Write-Host "Under: '$($word)' Path: $($subItem["FileRef"])" -ForegroundColor Yellow;

                        $permissions = @()
                        $perm = Get-PnPProperty -ClientObject $subItem -Property RoleAssignments       
                        foreach ($role in $subItem.RoleAssignments) {
                            $loginName = Get-PnPProperty -ClientObject $role.Member -Property LoginName
                            $rolebindings = Get-PnPProperty -ClientObject $role -Property RoleDefinitionBindings
                            $permissions += "$($loginName) - $($rolebindings.Name)"
                            # Write-Host "$($loginName) - $($rolebindings.Name)" -ForegroundColor Yellow
                        }
                        $permissions = $permissions | Out-String
           
                        $results = New-Object PSObject -Property @{
                            FileName = $subItem["FileLeafRef"]
                            FileExtension = $subItem["File_x0020_Type"]
                            FileSize = $subItem["File_x0020_Size"]
                            Path = $subItem["FileRef"]
                            Permissions = $permissions
                            Criteria = $word
                            Created = $subItem["Created"]
                            Modified = $subItem["Modified"]
                        }

                        if (test-path $reportPath) {
                            $results | Select-Object "FileName", "FileExtension", "FileSize", "Path", "Permissions", "Criteria", "Created", "Modified" | Export-Csv -Path $reportPath -Force -NoTypeInformation -Append
                        } else {
                            $results | Select-Object "FileName", "FileExtension", "FileSize", "Path", "Permissions", "Criteria", "Created", "Modified" | Export-Csv -Path $reportPath -Force -NoTypeInformation
                        }
                    }
                }
            }
        }
    }
}
