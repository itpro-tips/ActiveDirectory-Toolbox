The ADMX/ADML file can be found on Windows using the OneDrive client:  
`%ProgramFiles%\Microsoft OneDrive\<build number>\adm\`  

The `OneDrive.adml` file located in the root folder is the English file and must be placed in the `en-us` folder.  

Sub-folders correspond to localized folders for each language. For example, the folder for French is named `fr` instead of `fr-FR`. Note that the folder names have not been renamed to match the ADML folder names used in GPOs, so you will need to rename them manually if necessary.