Get-Item ~/.claude/skills/alba-* | remove-item -Force -Recurse;
Copy-Item $PSScriptRoot/skills/* ~/.claude/skills -recurse -Force