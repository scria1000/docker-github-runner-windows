##### BASE IMAGE INFO ######
#Using servercore insider edition for compacted size.
#For compatibility on "your" host running docker you may need to use a specific tag.
#E.g. the host OS version must match the container OS version. 
#If you want to run a container based on a newer Windows build, make sure you have an equivalent host build. 
#Otherwise, you can use Hyper-V isolation to run older containers on new host builds. 
#The default entrypoint is for this image is Cmd.exe. To run the image:
#docker run mcr.microsoft.com/windows/servercore/insider:10.0.{build}.{revision}
#tag reference: https://mcr.microsoft.com/en-us/product/windows/servercore/insider/tags

FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

ARG RUNNER_VERSION

LABEL Author="scria1000"
LABEL Email="91804886+scria1000@users.noreply.github.com"
LABEL GitHub="https://github.com/scria1000"
LABEL BaseImage="framework/runtime:4.8-windowsservercore-ltsc2019"
LABEL RunnerVersion=${RUNNER_VERSION}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

#Set working directory
WORKDIR /actions-runner

#Install chocolatey
ADD https://chocolatey.org/install.ps1 ./Install-Choco.ps1
RUN .\Install-Choco.ps1; \
    Remove-Item .\Install-Choco.ps1 -Force
	
RUN choco install -y powershell-core

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop';"]

WORKDIR /actions-runner

RUN choco install -y \
    7zip \
    aria2 \
    jq \
    git.install --params "'/GitAndUnixToolsOnPath /NoAutoCrlf /WindowsTerminalProfile /NoShellIntegration /NoCredentialManager'" \
    gh
	
RUN choco install -y vswhere

RUN Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module VSSetup -Force
	
RUN choco install -y visualstudio2019enterprise --params "'--nocache'"

RUN choco install -y visualstudio2019-workload-nativedesktop --params "'--includeRecommended --nocache --add Microsoft.VisualStudio.Component.VC.ATL --add Microsoft.VisualStudio.Component.VC.ATL.Spectre --add Microsoft.VisualStudio.Component.VC.ATLMFC --add Microsoft.VisualStudio.Component.VC.ATLMFC.Spectre --add Microsoft.VisualStudio.Component.Windows10SDK --add Microsoft.VisualStudio.Component.Windows11SDK.22000'"

RUN choco install -y visualstudio2019-workload-visualstudioextension

RUN choco install -y windowsdriverkit11

RUN Expand-Archive 'C:\\Program Files (x86)\\Windows Kits\\10\\Vsix\\VS2019\\WDK.vsix' -DestinationPath .\\WDKVSIX; \
	Copy-Item -Path '.\\WDKVSIX\\$MSBuild\\*' -Destination (Join-Path $(Get-VSSetupInstance).InstallationPath 'MSBuild') -Recurse -Force; \
	Remove-Item ".\\WDKVSIX" -Force -Recurse

#Download GitHub Runner based on RUNNER_VERSION argument (Can use: Docker build --build-arg RUNNER_VERSION=x.y.z)
RUN Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-x64-$env:RUNNER_VERSION.zip" -OutFile "actions-runner.zip"; \
    Expand-Archive -Path ".\\actions-runner.zip" -DestinationPath '.'; \
    Remove-Item ".\\actions-runner.zip" -Force

#Add GitHub runner configuration startup script
ADD scripts/start.ps1 .
ADD scripts/Cleanup-Runners.ps1 .
ENTRYPOINT ["pwsh.exe", ".\\start.ps1"]