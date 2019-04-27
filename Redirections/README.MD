# FSLogix Profile Containers Redirections

A list of folder redirections for use with FSLogix Profile Containers. See [Controlling the Content of the Profile Container](https://docs.fslogix.com/display/20170529/Controlling+the+Content+of+the+Profile+Container) for more details.

The list of redirections - `redirections.csv` is in CSV format to simplify display of the redirections data viewed on GitHub. 

## Creating Redirections.xml

`ConvertTo-RedirectionsXml.ps1` is used to convert the list into the correct XML format for use with Profile Containers. This script will read the `redirections.csv` from GitHub and output `redirections.xml` locally for use with Profile Containers.

## How To Contribute

Contributions to the list of folders to exclude or include from the Profile Container is needed to improve the list. There are two ways to contribute:

1. [Fork the repo](https://help.github.com/en/articles/fork-a-repo), update `redirections.csv` and create a [Pull Request](https://help.github.com/en/desktop/contributing-to-projects/creating-a-pull-request)
2. If would prefer not to create a pull request, you can instead [create a new issue to request an addition or improvement](https://github.com/aaronparker/FSLogix/issues/new?assignees=&labels=&template=custom.md&title=)
