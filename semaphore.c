#include <stdio.h>
#include <sys/stat.h>        /* For mode constants */
#include <fcntl.h>           /* For O_* constants */
#include <stdlib.h>
#include <semaphore.h>

static const char *shm_name_sync = "/sync";

int main(int argc) {
  sem_t *semaphore = sem_open(shm_name_sync, O_CREAT, S_IRUSR | S_IWUSR, 0);
  if (semaphore == SEM_FAILED) {
    perror("sem_open");
    exit(1);
  }
  
  int value = 0;
  if (sem_getvalue(semaphore, &value) < 0) {
    perror("sem_getvalue");
    exit(1);
  }

  if (argc > 1) {
    printf("signaling semaphore\n");
    sem_post(semaphore);
  } else {
    printf("waiting on semaphore...\n");
    sem_wait(semaphore);
  }

  printf("closing semaphore\n");
  sem_close(semaphore);
  return 0;
}

