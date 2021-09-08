// cc echo-server.c -o echo-server
#include <sys/types.h>          /* See NOTES */
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdio.h>

const char *socketfile = "/tmp/echo-server";

int main() {
  int sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, socketfile, sizeof(addr.sun_path)-1);
  bind(sockfd, (struct sockaddr*) &addr, sizeof(addr));
  listen(sockfd, 1);

  struct sockaddr_un client_addr;
  socklen_t client_addr_size = 0;
  int client_fd;
  while ((client_fd = accept(sockfd, (struct sockaddr*) &client_addr, &client_addr_size)) >= 0) {
    printf("connected to %i\n", client_fd);
    char buffer[10];
    read(client_fd, buffer, 10);
    write(client_fd, buffer, 10);
    close(client_fd);
  }
  perror("accept");
}

