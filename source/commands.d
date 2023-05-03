import std.file;
import std.path;
import std.format;
import std.string;
import std.algorithm;
import data;
import server;
import client;
import commandsManager;

void Commands_Help(string[] args, Client client) {
	auto cmds = Server.Instance().cmds;

	if (args.length == 0) {
		foreach (key, value ; cmds.commands) {
			client.SendMessage(key ~ ", ");
		}
		client.SendMessage("\n");
	}
	else {
		if (!cmds.CommandExists(args[0])) {
			client.SendMessage(format("No such command: %s\n", args[0]));
			return;
		}

		foreach (line ; cmds.commands[args[0]].help) {
			client.SendMessage(line ~ "\n");
		}
	}
}

void Commands_Exit(string[] args, Client client) {
	Server.Instance().KickClient(client.username);
	throw new CommandQuitException();
}

void Commands_Messages(string[] args, Client client) {
	auto server = Server.Instance();

	foreach (ref message ; server.messages) {
		client.SendMessage(message ~ '\n');
	}
}

void Commands_Send(string[] args, Client client) {
	if (args.length == 0) {
		client.SendMessage("No message\n");
		return;
	}

	string message;

	foreach (ref arg ; args) {
		message ~= arg ~ " ";
	}
	message = strip(message);

	Server.Instance().SendGlobalMessage(
		format(
			"\x1b[%dm%s\x1b[0m: %s",
			client.data.colour, client.username, message
		)
	);
}

void Commands_Users(string[] args, Client client) {
	auto server = Server.Instance();

	foreach (ref c ; server.clients) {
		if (c.authenticated) {
			client.SendMessage(c.username ~ "\n");
		}
	}
}

void Commands_Uptime(string[] args, Client client) {
	auto server = Server.Instance();
	auto time   = server.uptime.peek.total!"seconds";

	client.SendMessage(
		format(
			"%d days, %d hours, %d minutes and %d seconds\n",
			time / 86400,
			time % 86400 / 3600,
			time % 86400 % 3600 / 60,
			time % 86400 % 3600 % 60
		)
	);
}

void Commands_Motd(string[] args, Client client) {
	client.SendMessage(readText(dirName(thisExePath()) ~ "/motd.txt"));
}

void Commands_Clear(string[] args, Client client) {
	client.SendMessage("\x1b[2J\x1b[H");
}

void Commands_Ban(string[] args, Client client) {
	auto server = Server.Instance();

	if (args.length == 0) {
		client.SendMessage("IP required\n");
		return;
	}

	server.data.banList ~= args[0];
	server.data.Save();

	if (server.IPOnline(args[0])) {
		server.KickIP(args[0]);
	}
}

void Commands_Watch(string[] args, Client client) {
	auto server = Server.Instance();

	if (args.length == 0) {
		client.SendMessage("Username required\n");
		return;
	}

	server.data.watchList ~= args[0];
	server.data.Save();

	if (server.UserOnline(args[0])) {
		server.KickClient(args[0]);
	}
}

void Commands_SetRank(string[] args, Client client) {
	if (args.length < 2) {
		client.SendMessage("2 arguments required\n");
		return;
	}

	auto server = Server.Instance();

	UserRank[string] ranks = [
		"guest":     UserRank.Guest,
		"member":    UserRank.Member,
		"vip":       UserRank.Vip,
		"regular":   UserRank.Regular,
		"moderator": UserRank.Moderator,
		"operator":  UserRank.Operator
	];

	UserColour[string] rankColours = [
		"guest":     UserColour.Blue,
		"member":    UserColour.Blue,
		"vip":       UserColour.Green,
		"regular":   UserColour.Magenta,
		"moderator": UserColour.Yellow,
		"operator":  UserColour.Cyan
	];

	if (!server.data.UserExists(args[0])) {
		client.SendMessage("Unknown user\n");
		return;
	}

	try {
		auto temp = ranks[args[1]];
	}
	catch (Throwable) {
		client.SendMessage("Unknown rank\n");
		return;
	}
	
	User user   = server.data.GetUser(args[0]);
	user.rank   = ranks[args[1]];
	user.colour = rankColours[args[1]];

	server.data.WriteUser(args[0], user);
	server.data.Save();

	if (server.UserOnline(args[0])) {
		server.GetClient(args[0]).data = user;
	}
}

void Commands_Up(string[] args, Client client) {
	auto server = Server.Instance();

	if (client.previous.length == 0) {
		client.SendMessage("No command to repeat\n");
	}

	server.cmds.Run(client.previous, client);
}

void Commands_GetInfo(string[] args, Client client) {
	auto server = Server.Instance();

	if (args.length != 1) {
		client.SendMessage("1 argument required");
	}

	if (!server.data.UserExists(args[0])) {
		client.SendMessage("No such user exists");
	}

	auto user = server.data.GetUser(args[1]);

	client.SendMessage(format("Colour: %s\n", cast(UserColour) user.colour));
	client.SendMessage(format("Rank: %s\n", user.rank));
	client.SendMessage(format("XP: %d\n", user.xp));
	client.SendMessage(format("IP: %d\n", user.ip));
}

void Commands_AllUsers(string[] args, Client client) {
	auto server = Server.Instance();

	foreach (string key, value ; server.data.userData) {{
		client.SendMessage(format("%s\n", key));
	}}
}
