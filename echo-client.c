#include <sys/types.h>          /* See NOTES */
#include <sys/socket.h>
#include <sys/un.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main() {
  int sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
  struct sockaddr_un addr;
  memset(&addr, 0, sizeof (addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, "/tmp/server", sizeof (addr.sun_path)-1);

  if (connect(sockfd, (struct sockaddr*) &addr, sizeof (addr)) != 0) {
    perror("connect");
    exit(1);
  }

  write(sockfd, "Hello\n", 7);
  char buffer[10];
  read(sockfd, buffer, 10);
  printf("resp: %s", buffer);
}

