import std.ascii;

string CleanString(string str) {
	string ret;

	foreach (i, ref ch ; str) {
		if ((ch >= 32) && (ch <= 255)) {
			ret ~= ch;
		}
	}

	return ret;
}

string LowerString(string str) {
	string ret;

	foreach (ref ch ; str) {
		ret ~= ch.toLower();
	}

	return ret;
}
