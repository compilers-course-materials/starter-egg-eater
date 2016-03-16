#include <stdio.h>
#include <stdlib.h>

extern int our_code_starts_here() asm("our_code_starts_here");
extern void error(int err_code) asm("error");
extern int print(int val) asm("print");

const int TRUE = 0xFFFFFFFF;
const int FALSE = 0x7FFFFFFF;

int print(int val) {
  if(val & 0x00000001 ^ 0x00000001) {
    printf("%d", val >> 1);
  }
  else if(val == 0xFFFFFFFF) {
    printf("true");
  }
  else if(val == 0x7FFFFFFF) {
    printf("false");
  }
  else {
    printf("Unknown value: %#010x", val);
  }
  printf("\n");
  return val;
}

void error(int i) {
  if (i == 0) {
    fprintf(stderr, "Error: comparison operator got non-number");
  }
  else if (i == 1) {
    fprintf(stderr, "Error: arithmetic operator got non-number");
  }
  else if (i == 2) {
    fprintf(stderr, "Error: if condition got non-boolean");
  }
  else if (i == 3) {
    fprintf(stderr, "Error: Integer overflow");
  }
  else {
    fprintf(stderr, "Error: Unknown error code: %d\n", i);
  }
  exit(i);
}

int main(int argc, char** argv) {
  int* HEAP = calloc(100000, sizeof (int));

  int result = our_code_starts_here(HEAP);
  print(result);
  return 0;
}

