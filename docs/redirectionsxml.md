# FSLogix Profile Containers Redirections

A list of folder redirections for use with FSLogix Profile Containers and a method for generating the list in the expected XML format. See [Controlling the Content of the Profile Container](https://docs.fslogix.com/display/20170529/Controlling+the+Content+of+the+Profile+Container) for more details.

The list of redirections (`Redirections.csv`) is hosted here in CSV format so that it can be [rendered in a table when viewed on GitHub](https://help.github.com/en/articles/rendering-csv-and-tsv-data) and to simplify adding to or updating the list.

## Test Before Implementing in Production

`Redirections.csv` is not a definitive list of paths to exclude or include in the Profile Container. You should assess each of the paths included in this list for your environment and understand whether a path should be excluded or [cleaned up with alternative methods](https://github.com/aaronparker/fslogix/tree/main/Profile-Cleanup). It is likely that additional paths can be added to the list. With community feedback, this list can be improved.

It is also important to understand the performance impacts of implementing exclusions for Profile Containers. Ensure that the `redirections.xml` that you implement in your environment is well tested before moving into production.

## Install the Script

There are two methods for installing the script:

1. Install from the [PowerShell Gallery](https://www.powershellgallery.com/packages/ConvertTo-RedirectionsXml/). This is the preferred method as the installation can be handled directly from Windows PowerShell or PowerShell Core with the following command:

```powershell
Install-Script -Name ConvertTo-RedirectionsXml
```

2. Download from the [repository](https://github.com/aaronparker/fslogix). `ConvertTo-RedirectionsXml.ps1` can be downloaded directly from this repository and saved to a preferred location.

## Usage

`ConvertTo-RedirectionsXml` is used to convert the CSV list into the correct XML format for use with Profile Containers. This script will read the `Redirections.csv` from GitHub repo and output `Redirections.xml` locally for use with Profile Containers.

To output `Redirections.xml` to the current folder, just run the script without arguments.

```powershell
ConvertTo-RedirectionsXml
```

A custom path can be provided for the output file - for example, the following command will output the file to `C:\Temp\Redirections.xml`:

```powershell
ConvertTo-RedirectionsXml -OutFile C:\Temp\Redirections.xml
```

If you have saved the script locally instead of installing from the PowerShell Gallery, remember to run the script with the correct syntax:

```powershell
.\ConvertTo-RedirectionsXml.ps1
```

## How To Contribute

Contributions to the list of folders to exclude or include from the Profile Container is needed to improve the list. There are two ways to contribute:

1. [Fork the repo](https://help.github.com/en/articles/fork-a-repo), update `redirections.csv` and create a [Pull Request](https://help.github.com/en/desktop/contributing-to-projects/creating-a-pull-request)
2. If would prefer not to create a pull request, you can instead [create a new issue to request an addition or improvement](https://github.com/aaronparker/fslogix/issues/new?assignees=&labels=&template=custom.md&title=)
