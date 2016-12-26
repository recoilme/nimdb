#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "linklist.h"
#include "hashtable.h"

typedef struct {
    linked_list_t* list;
    hashtable_t* table; 
} cache2;

cache2 * create_cache();

void set(cache2 * cache, char * key, char ** value, int valueLen);

bool get(cache2 * cache, char * key, char ** value);
