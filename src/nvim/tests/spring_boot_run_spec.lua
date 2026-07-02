-- Headless assertions for the Spring Boot run helpers in
-- custom.actions.language. Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/spring_boot_run_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

-- dofile pins the test to the local copy of the module beside this spec.
local language = dofile(lua_root .. 'custom/actions/language.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- parse_pom_java_version: pull the major Java version from pom.xml text.
check('java.version wins', language.parse_pom_java_version('<properties><java.version>21</java.version></properties>'), '21')
check('maven.compiler.release when no java.version', language.parse_pom_java_version('<maven.compiler.release>17</maven.compiler.release>'), '17')
check('legacy 1.8 target normalizes to 8', language.parse_pom_java_version('<maven.compiler.target>1.8</maven.compiler.target>'), '8')
check('bare <release> tag', language.parse_pom_java_version('<configuration><release>11</release></configuration>'), '11')
check('unresolved property ref -> nil', language.parse_pom_java_version('<maven.compiler.release>${java.version}</maven.compiler.release>'), nil)
check('no version -> nil', language.parse_pom_java_version('<project><artifactId>x</artifactId></project>'), nil)
check('java.version preferred over release', language.parse_pom_java_version('<release>17</release><java.version>21</java.version>'), '21')

-- pom_declares_spring_boot: true only when the boot maven plugin is present.
check(
  'spring-boot-maven-plugin -> true',
  language.pom_declares_spring_boot('<build><plugins><plugin><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>'),
  true
)
check(
  'plain library pom -> false',
  language.pom_declares_spring_boot('<build><plugins><plugin><artifactId>maven-compiler-plugin</artifactId></plugin></plugins></build>'),
  false
)

-- resolve_sdkman_java_home: map a major version to the installed Temurin JDK
-- home. HOME is injected so the test does no real filesystem IO.
local candidates = { '17.0.19-tem', '21.0.11-tem', 'current' }
check('resolves Java 21 home', language.resolve_sdkman_java_home('21', candidates, { home = '/h' }), '/h/.sdkman/candidates/java/21.0.11-tem')
check('resolves Java 17 home', language.resolve_sdkman_java_home('17', candidates, { home = '/h' }), '/h/.sdkman/candidates/java/17.0.19-tem')
check('uninstalled version -> nil', language.resolve_sdkman_java_home('11', candidates, { home = '/h' }), nil)
check('partial-digit does not mismatch', language.resolve_sdkman_java_home('1', candidates, { home = '/h' }), nil)
check('ignores the current symlink', language.resolve_sdkman_java_home('21', { 'current' }, { home = '/h' }), nil)
-- Prefer Temurin, newest patch, when several match the major.
check(
  'prefers newest Temurin patch',
  language.resolve_sdkman_java_home('21', { '21.0.1-tem', '21.0.11-tem', '21.0.2-tem' }, { home = '/h' }),
  '/h/.sdkman/candidates/java/21.0.11-tem'
)

-- build_spring_boot_run_command: byte-exact command assembly.
check('defaults: root, local profile, no JDK pin', language.build_spring_boot_run_command({}), 'mvn spring-boot:run -Dspring-boot.run.profiles=local -Dmaven.gitcommitid.skip=true')
check('with module', language.build_spring_boot_run_command({ module = 'app' }), 'mvn -pl app spring-boot:run -Dspring-boot.run.profiles=local -Dmaven.gitcommitid.skip=true')
check(
  'with module and JDK pin',
  language.build_spring_boot_run_command({ module = 'bank-loan-rest-api-app', java_home = '/h/j21' }),
  'JAVA_HOME="/h/j21" mvn -pl bank-loan-rest-api-app spring-boot:run -Dspring-boot.run.profiles=local -Dmaven.gitcommitid.skip=true'
)
check('custom profile', language.build_spring_boot_run_command({ profile = 'dev' }), 'mvn spring-boot:run -Dspring-boot.run.profiles=dev -Dmaven.gitcommitid.skip=true')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall spring boot run assertions passed\n')
os.exit(0)
