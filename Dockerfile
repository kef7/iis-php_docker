# BUILD WTIH CMD (from where Dockerfile is): 
# > docker build -t kef7/iis-php .

# NOTE: DON'T USE " USE ', IN: RUN powershell -Command $var = ''; write-host $var;

# NOT READY FOR THIS YET, IDK!!!
# RESOURCES:
# https://blog.sixeyed.com/how-to-dockerize-windows-applications/
# https://hub.docker.com/r/microsoft/windowsservercore/
# https://docs.microsoft.com/en-us/iis/application-frameworks/install-and-configure-php-on-iis/install-php-and-fastcgi-support-on-server-core
# https://www.assistanz.com/steps-to-install-php-manually-on-windows-2016-server/

FROM mcr.microsoft.com/windows/servercore:ltsc2016

LABEL maintainer="kef7"

# Install IIS and FastCGI features
RUN powershell -Command \
    Install-WindowsFeature -Name web-server, web-cgi;

# Expose default HTTP & HTTPS port
EXPOSE 80
EXPOSE 443

# Download and install PHP; test hash to see if zip has been modified also
ENV PHP_HOME="C:\php"
RUN powershell -Command \
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'; \
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols; \
    Invoke-WebRequest -UseBasicParsing -Uri 'https://windows.php.net/downloads/releases/php-7.3.0-Win32-VC15-x64.zip' -OutFile 'C:\php.zip'; \
    if ((Get-FileHash 'C:\php.zip' -Algorithm sha256).Hash -ne '8bc4e2cbfe8b17b9a269925dd005a23a9b8c07f87965b9f70a69b1420845d065') { exit 1 }; \
    Expand-Archive -Path 'C:\php.zip' -DestinationPath $env:PHP_HOME; \
    Remove-Item 'C:\php.zip'; \
    Move-Item ($env:PHP_HOME + '\php.ini-development') ($env:PHP_HOME + '\php.ini'); \
    $env:PATH = $env:PATH + ';' + $env:PHP_HOME; \
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine);
    # ABOVE: Defien supported sec protocol versions; Set supported sec protocol versions; DL PHP zip file from php.net; Check zip file hash; Unzip file; 
    #   Remove zip file; Move unziped data into PHP home; Contact PHP home into env PATH; Set new PATH in env

# Configure IIS for PHP support by added php-cgi.exe as FastCGI module and by adding a handler for PHP files 
RUN %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/fastCGI /+[fullPath='C:\php\php-cgi.exe']
RUN %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/handlers /+[name='PHP-FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='C:\php\php-cgi.exe',resourceType='Either']

# Install Visual C++ Redistributable 2015 that maybe used by PHP
ADD https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe /vc_redist.x64.exe
RUN C:\vc_redist.x64.exe /quiet /install

# Install ServiceMonitor.exe from MS to set as the entry point of this image
RUN powershell -Command \
    Invoke-WebRequest -UseBasicParsing -Uri "https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.6/ServiceMonitor.exe" -OutFile "C:\ServiceMonitor.exe";

# Set entry point; setup docker to run ServiceMonitor.exe that will monitor IIS (w3svc)
ENTRYPOINT [ "C:\\ServiceMonitor.exe", "w3svc" ]