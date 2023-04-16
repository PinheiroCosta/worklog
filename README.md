# worklog

### Time management tool

worklog is a tool designed for time management. It purpose consist in record events of a given project name and save them into a log file.

### Features
- Creates START, PAUSE, RESUME, and END events
- Record events into a log file

### How to use
As default behavior worklog reads a the configuration file located in conf/ directory.  
To start using it just invoke the main script with the flag -p PROJECT_NAME, and -s STATUS_NAME:  
`worklog.sh -p MY_AWESOME_PROJECT -s START`  
  
It will create a log file with the timestamp and the string format defined in the config file.  
You can overwrite the log directory defined in the config file by passing the -d parameter:  
`worklog.sh -p SOME_OTHER_PROJECT -s START -d path/to/log/here/events.log`  


### TODO
- [] add option to query for total work hours of a given date.
- [] add option to query for total work hours of a given date range.
