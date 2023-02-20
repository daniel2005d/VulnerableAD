param ([int]$totaluserstocreate=5,
[switch]$clean)

if (-not $clean){
    $users = [System.Collections.ArrayList](Get-Content .\data\users.txt)
    $lastnames = [System.Collections.ArrayList](Get-Content .\data\lastnames.txt)
    $passwords = [System.Collections.ArrayList](Get-Content .\data\passwords.txt)
    $groups = [System.Collections.ArrayList](Get-Content .\data\groups.txt)
}

$Global:Domain = "gaby.local"

function RemovePasswordPolicy(){
    secedit /export /cfg secpol.cfg 
    (gc secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0").Replace("MinimumPasswordLength = 7","MinimumPasswordLength = 1")  | Out-File secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg secpol.cfg /areas SECURITYPOLICY
    rm -for secpol.cfg -confirm:$false
}

function RecoveryPolicy(){
    secedit /export /cfg secpol.cfg 
    (gc secpol.cfg).replace("PasswordComplexity = 0", "PasswordComplexity = 1").Replace("MinimumPasswordLength = 1","MinimumPasswordLength = 7")  | Out-File secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg secpol.cfg /areas SECURITYPOLICY
    rm -for secpol.cfg -confirm:$false
}
function TryRemove-AdUser([string]$username){
    try{
        Remove-AdUser -Identity $username -Confirm:$false
    }
    catch{}
}
function Add-ADGroup([string]$username){
    $group = (Get-Random -InputObject $groups)
    try{
        get-adgroup -Identity $group
    }
    catch{
        New-ADGroup -name $group -GroupScope Global
    }

    Add-AdGroupMember -Identity $group -Members $username
}
function Add-AdUser(){
    $firstname = (Get-Random -InputObject $users).ToLower()
    $lastname = (Get-Random -InputObject $lastnames).ToLower()
    $SamAccountName = "{0}.{1}" -f ($firstname, $lastname).ToLower()
    $principalname  = "{0} {1}" -f ($firstname, $lastname).ToLower()
    $generated_password = (Get-Random -InputObject $passwords)
    TryRemove-AdUser $principalname
    $log = "Creating user {0} with password {1}." -f ($SamAccountName, $generated_password)
    Write-Host $log -ForegroundColor Green
    New-ADUser -Name "$firstname $lastname" -GivenName $firstname -Surname $lastname -SamAccountName $SamAccountName -UserPrincipalName $principalname@$Global:Domain -AccountPassword (ConvertTo-SecureString $generated_password -AsPlainText -Force) -PassThru | Enable-ADAccount 
    
    Add-ADGroup $SamAccountName

    $users.remove($username)
    $lastnames.remove($lastname)
    $passwords.Remove($generated_password)
}

function RemoveAdUsers(){
    $users = (get-aduser -Filter * )
    foreach($u in $users){
        Write-Host "Removing " $u.SamAccountName -ForegroundColor Yellow
        if ($u -ne "Administrator" -or $u -ne "Guest" -or $u -ne "krbtgt" ){
            TryRemove-AdUser $u.SamAccountName
        }
    }
}

if (-not $clean){
    RemovePasswordPolicy
    
    for($i=0;$i -le $totaluserstocreate;$i++){
        Add-AdUser
    }

    RecoveryPolicy
}
else{
    RemoveAdUsers
}

