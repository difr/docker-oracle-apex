# Oracle APEX Docker Image

* Oracle Linux 7.7
* Oracle Database XE 18c
* Oracle Java SE Development Kit 8u241
* Oracle APEX 19.2
* Oracle REST Data Services 19.4
* Apache Tomcat 9.0.31

See more in "Dockerfile".
To build image run "buildImage.sh".

! All container's data consolidated into single folder "/u02", which you can bind to any host's folder.
! All passwords are new generated, you can find them in "/u02/{oracle,tomcat}/.pwds".
See more in "runImage.sh".
