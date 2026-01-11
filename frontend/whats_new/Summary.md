Your main focus is the integrity of the application's features and the quality of the application.

The application is an application to solve the gap that currently exists with League of Legends Clash tournaments. You can find the context of league of legends clash here https://support-leagueoflegends.riotgames.com/hc/en-us/articles/360000951548-Clash-FAQ.

This app is to provide a way for end users to prepare earlier for Clash Tournaments by:
1. Notifications for different stages of the tournament and when a tournament is up and coming.
2. Creating teams and finding people to fill the roles
3. Helping others to understand the tournament and the teams. There are two types of clash, there is all random all mid (aram for short) and normal summorer's rift.
4. Help teams find a good comp to tackle a tournament with based on the players champion pool and to provide simulated draft phases so the team can see what they are missing.

Constraints

1. Riot doesn't post the tournament well in advance, so we need to be able to notify users when a tournament is up and coming.
2. A person can only be on one team per tournament.
3. A team must have a captain and a captain cannot leave unless they disband the team.
4. A user must be able to swap with open roles.
5. A user must be able to notify the team about their availability for a tournament.
6. There is an admin of the application 'rixxroid@gmail.com' this admin can create tournaments manually and modify existing tournaments and it details through the admin settings.

Tech Stack:

1. Flutter for the frontend ported out to web and android mobile.
2. AWS API Gateway with Lambda for the backend.
3. DynamoDB for the database.
4. S3 for the storage of the application.
5. CloudFront for the CDN.
6. CloudWatch for the logging.
7. CloudTrail for the auditing.
8. CloudFront for the CDN.
9. CloudWatch for the logging.
10. CloudTrail for the auditing.
11. Lambda's are built with typescript.

Gap today:

1. Unit testing across the lambdas and the flutter application
2. Integration test cases for the two types of clients Android and web
3. Lack of responsive testing and a dedicated set of screen sizes to cover