# README

Directory serving as the BaseDirectory for using [`Import-LocalizedData`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-localizeddata) in private functions.  As such, directory layout and filenames are goverened by the requirements of that function

In short: all directory names should either be a language code or a language-country code, i.e., `de` (German) or `ar-SA` (Saudi Arabian Arabic).  Within each directory, localizations for a particular file are stored in `.psd1` of the same name.

## Example Directory Layout

```
└── Test-Function.ps1
    └── localization
        ├── de
        │   └── Test-Function.psd1
        └── ar-SA
            └── Test-Function.psd1
```

## See Also
For more details, refer to PowerShell documentation, specifically [about_Script_Internationalization](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_script_internationalization) and [Import-LocalizedData](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-localizeddata).
