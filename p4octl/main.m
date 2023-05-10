#include <stdio.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <spawn.h>

char *getProcessNameFromPID(int pid) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
    struct kinfo_proc kp;
    size_t size = sizeof(kp);
    char *name = malloc(MAXCOMLEN+1);

    if (sysctl(mib, sizeof(mib)/sizeof(*mib), &kp, &size, NULL, 0) < 0) {
        return NULL;
    }

    strncpy(name, kp.kp_proc.p_comm, MAXCOMLEN);
    name[MAXCOMLEN] = '\0';

    return name;
}

void doSafeMode(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"killall", "-SEGV", "SpringBoard", NULL};
	posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

void doReboot(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"reboot", NULL};
	posix_spawn(&pid, "/var/jb/sbin/reboot", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

void doUICache(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"uicache", "--all", "--respring", NULL};
	posix_spawn(&pid, "/var/jb/usr/bin/uicache", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

void doUserSpaceReboot(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"launchctl", "reboot", "userspace", NULL};
	posix_spawn(&pid, "/var/jb/usr/bin/launchctl", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

void doLDRestart(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"ldrestart", NULL};
	posix_spawn(&pid, "/var/jb/usr/bin/ldrestart", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

int main(int argc, char *argv[], char *envp[]) {

	pid_t pid = getppid();
	char *name = getProcessNameFromPID(pid);
	

  	if (strcmp(name, "SpringBoard") != 0) {
    	fflush(stdout);
    	return 1;
  	}

	setuid(0);
	if (getuid() != 0) {
		return 1;
	}

	if (argc > 1) {
		if (strcmp(argv[1], "--safemode") == 0) {
			doSafeMode();
    	}

		if (strcmp(argv[1], "--reboot") == 0) {
			doReboot();
    	}

		if (strcmp(argv[1], "--uicache") == 0) {
			doUICache();
    	}

		if (strcmp(argv[1], "--ldrestart") == 0) {
			doLDRestart();
    	}

		if (strcmp(argv[1], "--userspacereboot") == 0) {
			doUserSpaceReboot();
    	}
	}
	return 0;
}
