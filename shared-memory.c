#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <semaphore.h>

int main() {
  int shfd = shm_open("/test", O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
  ftruncate(shfd, 10);
  char *map = mmap(NULL, 10, PROT_READ | PROT_WRITE, MAP_SHARED, shfd, 0);
  if (map == MAP_FAILED) {
    perror("mmap");
    exit(1);
  }
  for (int i = 0; i < 10; ++i) {
    map[i] = i;
  }

  sem_t *semaphore = sem_open("semaphore", O_CREAT, S_IRUSR | S_IWUSR, 0);
  if (semaphore == SEM_FAILED) {
    perror("sem_open");
    exit(1);
  }
  
  printf("waiting...\n");
  sem_wait(semaphore);

  munmap(map, 10);
  /* shm_unlink("/test"); */
}
