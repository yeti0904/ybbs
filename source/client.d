import std.utf;
import std.file;
import std.path;
import std.ascii;
import std.array;
import std.stdio;
import std.string;
import std.socket;
import std.format;
import std.algorithm;
import passwd;
import passwd.bcrypt;
import data;
import util;
import server;
import terminal;
import commandsManager;

enum AuthenticationStage {
	Username,
	Password
}

class Client {
	Socket              socket;
	ubyte[]             inBuffer;
	bool                authenticated;
	string              username;
	AuthenticationStage authStage;
	User                data;
	string[]            previous;

	this() {
		authenticated = false;
		authStage     = AuthenticationStage.Username;
	}

	void SendMessage(string pmsg) {
		auto msg = pmsg.replace("\n", "\r\n");
		
		while (msg.length > 0) {
			auto len = socket.send(cast(void[]) msg);

			if (len == Socket.ERROR) {
				Server.Instance().KickMe(this);
			}

			msg = msg[len .. $];
		}
	}

	bool HandleInput() {
		string input  = strip(cast(string) inBuffer).CleanString();
		auto   server = Server.Instance();

		try {
			input.validate();
		}
		catch (UTFException) {
			server.KickMe(this);
		}

		if (input.length == 0) {
			inBuffer = [];
			return true;
		}
		
		if (authenticated) {
			string[] parts;

			try {
				parts = input.split!isWhite();
			}
			catch (UTFException e) {
				SendMessage(e.msg ~ "\n> ");
				return true;
			}

			if (parts.length == 0) {
				SendMessage("Command not given\n> ");
				return true;
			}
			
			if (!server.cmds.CommandExists(parts[0])) {
				SendMessage(format("No such function: %s\n> ", parts[0]));
				return true;
			}

			auto cmd = server.cmds.commands[parts[0]];

			if (data.rank < cmd.minRank) {
				SendMessage(
					format(
						"You can't run this command (you are %s, requires %s)\n> ",
						data.rank, cmd.minRank
					)
				);
				return true;
			}

			try {
				server.cmds.Run(parts, this);
			}
			catch (CommandQuitException) {
				return true;
			}

			if (parts[0] != "up") {
				previous = parts;
			}
			
			SendMessage("> ");
		}
		else {
			switch (authStage) {
				case AuthenticationStage.Username: {
					username = strip(input);
					SendMessage("Password: " ~ hideText);
					authStage = AuthenticationStage.Password;
					break;
				}
				case AuthenticationStage.Password: {
					if (server.data.UserExists(username)) {
						auto user = server.data.GetUser(username);

						data = user;

						if (!input.canCryptTo(user.password)) {
							authStage = AuthenticationStage.Username;

							SendMessage(showText ~ "Incorrect login\n");
							return false;
						}
					}
					else {
						User user;

						user.password = cast(string) input.CleanString().crypt(Bcrypt.genSalt());
						user.colour   = UserColour.Blue;
						user.rank     = UserRank.Guest;
						user.xp       = 0;

						data = user;

						server.data.WriteUser(username.CleanString(), user);
						server.data.Save();

						SendMessage(showText ~ "\nCreated account\n");
					}
				
					SendMessage(showText ~ "\nWelcome, " ~ username ~ "!\n");
					authenticated = true;

					if (server.data.watchList.canFind(username)) {
						SendMessage("You are banned from this BBS\n");

						server.data.banList ~= socket.remoteAddress.toAddrString();
						server.data.Save();

						socket.close();
						return false;
					}

					SendMessage(format("You have %d XP\n", data.xp));
					SendMessage("> ");
					break;
				}
				default: assert(0);
			}
		}

		return true;
	}
}
