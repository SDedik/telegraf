# Versions

## 1.3
Renamed Module Name from TelegrafAgent -> Telegraf

Ensure property has been marked as 'required'

## 1.2

Added checks that Windows Service is configured to use correct configuration file. If it is using some custom filename or file path is outside
of Telegraf folder, service is removed and re-installed using correct telegraf.conf

Added parameters validation for Test and Set functions when Ensure is set to Present

## 1.1

Key attribute property has been moved from 'Ensure' property to 'IsSingleInstance' property to comply with Microsoft guidelines on DSC Resource development

## 1.0

Initial release