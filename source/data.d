import std.file;
import std.path;
import std.json;
import std.array;
import std.stdio;
import util;

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
	string   ip;
}

// i hope using JSON as a database isn't a bad idea

class DataManager {
	JSONValue userData;
	string[]  watchList;
	string[]  banList;

	this() {
		string folder = dirName(thisExePath());
	
		if (!exists(folder ~ "/data")) {
			mkdir(folder ~ "/data");
		}

		string[] dataFiles = [
			folder ~ "/data/users.json",
			folder ~ "/data/banlist.json",
			folder ~ "/data/watchlist.json"
		];

		foreach (ref file ; dataFiles) {
			if (!exists(file)) {
				std.file.write(file, "{}");
			}
		}

		userData  = readText(folder ~ "/data/users.json").parseJSON();
		watchList = readText(folder ~ "/data/watchlist.json").split('\n');
		banList   = readText(folder ~ "/data/banlist.json").split('\n');

		foreach (string key, value ; userData) { // update old data
			if ("ip" !in value) {
				value["ip"] = "127.0.0.1";
			}
		}
	}

	User GetUser(string name) {
		assert(UserExists(name));

		UserRank[] ranks = [
			UserRank.Guest,
			UserRank.Member,
			UserRank.Vip,
			UserRank.Regular,
			UserRank.Moderator,
			UserRank.Operator,
		];
	
		User ret;
		auto data = userData[name].object;

		ret.password = data["password"].str;
		ret.colour   = cast(int) data["colour"].integer;
		ret.rank     = ranks[data["rank"].integer];
		ret.xp       = cast(int) data["xp"].integer;
		ret.ip       = data["ip"].str;

		return ret;
	}

	void WriteUser(string name, User user) {
		JSONValue value = parseJSON("{}");

		value["password"] = user.password;
		value["colour"]   = user.colour;
		value["rank"]     = cast(int) user.rank;
		value["xp"]       = user.xp;
		value["ip"]       = user.ip;

		userData[name] = value;
	}

	bool UserExists(string name) {
		if (name in userData) {
			return true;
		}
		return false;
	}

	bool UserExistsCI(string name) {
		foreach (string key, value ; userData) {
			if (key.LowerString() == name.LowerString()) {
				return true;
			}
		}

		return false;
	}

	string GetNameCase(string name) {
		foreach (string key, value ; userData) {
			if (key.LowerString() == name.LowerString()) {
				return key;
			}
		}

		assert(0);
	}

	size_t AccountsWithIP(string ip) {
		size_t ret;
	
		foreach (string key, value ; userData) {
			if (value["ip"].str == ip) {
				++ ret;
			}
		}

		return ret;
	}

	void Save() {
		std.file.write(dirName(thisExePath()) ~ "/data/users.json", userData.toString());
		std.file.write(dirName(thisExePath()) ~ "/data/watchlist.json", watchList.join('\n'));
		std.file.write(dirName(thisExePath()) ~ "/data/banlist.json", banList.join('\n'));
	}
}
