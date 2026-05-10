param(
    [string]$EngineRepositoryUrl = "https://github.com/EpicGames/UnrealEngine",
    [string]$EngineBranch = "5.2",
    [string]$WorkspaceDir,
    [string]$UE5Root,
    [string]$LyraContentDir,
    [string]$LyraMainBranch = "lyra-main",
    [string]$LyraApiBranch = "lyra-api",
    [string]$GameBranch = "lyra-game",
    [string]$GameName = "Lyra"
)

if ([string]::IsNullOrEmpty($EngineRepositoryUrl) -or
    [string]::IsNullOrEmpty($EngineBranch) -or
    [string]::IsNullOrEmpty($WorkspaceDir) -or
    [string]::IsNullOrEmpty($UE5Root) -or
    [string]::IsNullOrEmpty($LyraContentDir))
{
    Write-Host "Please provide all mandatory parameters: -WorkspaceDir, -UE5Root, -LyraContentDir"
    Write-Host "Additional parameters: -EngineRepositoryUrl, -EngineBranch, -LyraMainBranch, -LyraApiBranch, -GameBranch, -GameName"
    Exit
}

# Set Variables
$LyraSourceDir = "$UE5Root/Samples/Games/Lyra"

# cd to the PARENT of the $UE5Root directory.
# This directory must exist. Create it if needed.
cd $UE5Root/..

# Check if $UE5Root exists
if (Test-Path $UE5Root -PathType Container) {
    # $UE5Root exists; cd into it
    Set-Location $UE5Root

    # Switch branches if $EngineBranch is not the current branch
    $isCorrectBranch = git rev-parse --abbrev-ref HEAD
    if ($isCorrectBranch -ne $EngineBranch) {
        git fetch origin
        git checkout $EngineBranch
    }

    # pull latest from origin
    git pull origin
}
else {
    # $UE5Root does not exist; clone $EngineRepositoryUrl into $UE5Root
    git clone --branch $EngineBranch $EngineRepositoryUrl $UE5Root
}

# Create the WorkspaceDir directory if it doesn't exist
if (!(Test-Path $WorkspaceDir)) {mkdir $WorkspaceDir}

# Change the current directory to WorkspaceDir
cd $WorkspaceDir

# Initialize Git
git init

# TODO: Custom path parameters?
# Check if .gitignore exists; if not, download from Gist
if (!(Test-Path -Path ".gitignore")) {
    Write-Host "Downloading .gitignore file..."
    Invoke-WebRequest -Uri "https://gist.githubusercontent.com/RemainingToast/ac757969ab49b1cc969293481b280b77/raw/.gitignore" -OutFile ".gitignore"
}

# Check if .gitattributes exists; if not, download from Gist
if (!(Test-Path -Path ".gitattributes")) {
    Write-Host "Downloading .gitattributes file..."
    Invoke-WebRequest -Uri "https://gist.githubusercontent.com/RemainingToast/ac757969ab49b1cc969293481b280b77/raw/.gitattributes" -OutFile ".gitattributes"
}

# Add and commit the files
git add .gitignore .gitattributes
git commit -m "misc: initial import of lyra"

# Checkout lyra-main
git checkout -b $LyraMainBranch

# Example: Recursive Copy E:/GitHub/UnrealEngine/Samples/Games/Lyra/* into Workspace dir
Copy-Item -Force -Recurse $LyraSourceDir/* $WorkspaceDir

git add --all
git commit --amend -m "misc: initial import of lyra"

# This function copies a specific Content folder from the Sample project into our Workspace
function CopyLyraContentFolder()
{
  param( [Parameter()] $ContentFolder,
         [Parameter()] $DirPrefix    )
  # Remove the leading $ContentFolder from the name
  $RelativeContentFolder = $ContentFolder.FullName.substring($DirPrefix.length)
  # Add leading $WorkspaceDir folder to the name
  $WorkspaceContentFolder = "$WorkspaceDir/$RelativeContentFolder"
  # Create the directory if it does not exist
  if (!(Test-Path $WorkspaceContentFolder)) {mkdir $WorkspaceContentFolder}
  $WorkspaceContentFolder = Get-Item $WorkspaceContentFolder
  # Recursively copy Content into our Workspace, overwriting the Workspace as needed
  Write-Host "COPY: $($ContentFolder.FullName) => $($WorkspaceContentFolder.FullName)"
  Copy-Item -Force -Recurse "$($ContentFolder.FullName)/*" $WorkspaceContentFolder
}

# Get a list of all 'Content' folders in the sample dir

$LyraContentFolders = Get-ChildItem $LyraContentDir -Recurse -Directory `
    | Where-Object {$_.Name -ieq 'Content'}

# To see all the Lyra Content Folder names:
$LyraContentFolders | %{$_.FullName}

# Copy all the 'Content' folders into the $WorkspaceDir

$DirPrefix = (Get-Item $LyraContentDir).FullName
foreach ($ContentFolder in $LyraContentFolders)
{
  $NewFolder =& CopyLyraContentFolder $ContentFolder -DirPrefix:$DirPrefix
}

# Rename uproject to desired GameName
Get-ChildItem *.uproject | Rename-Item -NewName "$GameName.uproject"

# Commit Lyra Content to Git
git add --all  # This might take a while...
git commit --amend -m "misc: initial import of lyra"

# Change to the WorkspaceDir
Set-Location -Path $WorkspaceDir

# Ensure that $LyraMainBranch exists and is up-to-date
git checkout $LyraMainBranch

# Create and checkout $LyraApiBranch
git checkout -b $LyraApiBranch

# Create and checkout $GameBranch
git checkout -b $GameBranch

# Clean up default branch
# Get a list of all local branches except the ones we want to keep
$branchesToDelete = git branch | ForEach-Object { $_.TrimStart('*').Trim() } | Where-Object { $_ -notin @($LyraMainBranch, $LyraApiBranch, $GameBranch) }

# Delete the branches
$branchesToDelete | ForEach-Object {
    git branch -D $_
}

# Ensure main lyra branch
Set-Location -Path $WorkspaceDir
git checkout $LyraMainBranch