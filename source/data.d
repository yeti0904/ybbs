import std.file;
import std.path;
import std.json;

enum UserRank {
	Guest,
	Member,
	Vip,
	Regular,
	Moderator,
	Operator,

	Length
}

enum UserColour {
	Red     = 31,
	Green   = 32,
	Yellow  = 33,
	Blue    = 34,
	Magenta = 35,
	Cyan    = 36,
	White   = 37,
}

struct User {
	string   password; // hashed!!!
	int      colour;
	UserRank rank;
	int      xp;
}

// i hope using JSON as a database isn't a bad idea

class DataManager {
	JSONValue userData;

	this() {
		if (!exists(dirName(thisExePath()) ~ "/data")) {
			mkdir(dirName(thisExePath()) ~ "/data");
		}

		string[] dataFiles = [
			dirName(thisExePath()) ~ "/data/users.json"
		];

		foreach (ref file ; dataFiles) {
			if (!exists(file)) {
				write(file, "{}");
			}
		}

		userData = readText(dirName(thisExePath()) ~ "/data/users.json").parseJSON();
	}

	User GetUser(string name) {
		assert(UserExists(name));
	
		User ret;
		auto data = userData[name].object;

		ret.password = data["password"].str;
		ret.colour   = cast(int) data["colour"].integer;
		ret.rank     = cast(UserRank) data["rank"].integer;
		ret.xp       = cast(int) data["xp"].integer;

		return ret;
	}

	void WriteUser(string name, User user) {
		JSONValue value = parseJSON("{}");

		value["password"] = user.password;
		value["colour"]   = user.colour;
		value["rank"]     = cast(int) user.rank;
		value["xp"]       = user.xp;

		userData[name] = value;
	}

	bool UserExists(string name) {
		if (name in userData) {
			return true;
		}
		return false;
	}

	void Save() {
		write(dirName(thisExePath()) ~ "/data/users.json", userData.toString());
	}
}
