# DiscoveryTool-Se7en
  This Powershell script can scan and discover information about Ubiquiti and Cambium products. It will also let you export the information to a .txt or .csv file. Useful to help manage small or large wireless networks.
  
  The .txt files can be useful for saving all the devices at a location so that the IPs, Names, and Macs can be viewed from a central location. The .csv can be useful for 
  
  data manipulation if you have large networks you want to sort or filter. (Similar some of the features of UISP can but local and doesn't require internet)


#--What to look out for

  This tool has primarily been developed for Ubiquiti wireless units. Like Litebeams and some APs. This means I don't have a lot of testing or development outside those items.
  
  The Cambium Discovery is somewhat experimental. I made it because some cambium units showed up in my life and thought adding fuctionality would be useful, turns out they left as fast as they entered.
  
  I only had 2 units to test with so unlike the ubiquiti where I have tested it on close to 1000 units, the cambium is not near as tested and may not function as well. I also know there is a better
  
  way to make the cambium discovery work, however it required downloading extra resources, which I was trying to avoid across this entire project.


#--How to edit

  The Update Tool checks the hash of the two files (For both the main tool and updater). Meaning that if you change anything it will think that there is an update or needs repair. To make edits you need to edit the run file and-
  
  swap the comments to run the powershell script directly. This will skip the updates/repairs entirely.


#--About Me and why I made it.

  I made this script to make my life easier at my job. As most random scripts end up getting made. So with that, I am aware that it may not be the most effiecient or the most feature rich script.
  
  I learned powershell just for this. I chose powershell because it is pre-installed on all windows machines now, and I got tired of trying to downgrade java for the official Ubiquiti Discovery Tool
  
  that was abandoned. Powershell allowed me to just drop the files on any computer and have it work right away without needing to download or install any other programs. Which sometimes the machines I
  
  need the tool on do not have internet, making install some programs more difficult. Thats about it as to why I made this darn thing.
