using System;

public class CPHInline
{
    public bool Execute()
    {
        // Get the user who triggered the command
        string userName = CPH.GetUser();
        string userId = CPH.GetUserId();

        // Debug: Log the values
        CPH.LogInfo($"Checking follower status for: {userName} (ID: {userId})");

        // Check if user is a follower (correct method signature)
        bool isFollower = CPH.TwitchIsUserFollowing(userId, CPH.TwitchGetBroadcastUserId());

        // Debug: Log the result
        CPH.LogInfo($"Is follower result: {isFollower}");

        // Store the result in a variable that can be used by other actions
        CPH.SetGlobalVar("isFollower", isFollower, false);

        // If not a follower, send a message and stop execution
        if (!isFollower)
        {
            CPH.SendMessage($"@{userName}, you must be a follower to use this command!");
            CPH.LogInfo($"User {userName} blocked - not a follower");
            return false; // Returning false stops the action queue
        }

        // Debug: Confirm follower status
        CPH.SendMessage($"@{userName} is a verified follower. Command proceeding...");
        CPH.LogInfo($"User {userName} verified as follower");

        return true;
    }
}
