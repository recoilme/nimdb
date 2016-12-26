#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "linklist.h"
#include "hashtable.h"
#include <pthread.h>
#include <unistd.h>
#include <libgen.h>
#include <time.h>
#include <sys/time.h>


typedef struct {
    linked_list_t* list;
    hashtable_t* table; 
} cache2;

/*
int
slice_foreach_value(slice_t *slice, int (*item_handler)(void *item, size_t idx, void *user), void *user)
{
    linked_list_t *list = slice->list;
    MUTEX_LOCK(list->lock);
    size_t idx = 0;
    list_entry_t *e = pick_entry(list, slice->offset);
    while(e && idx < slice->length) {
        int rc = item_handler(e->value, idx++, user);
        if (rc == 0) {
            break;
        } else if (rc == -1 || rc == -2) {
            list_entry_t *d = e;
            e = e->next;
            if (list->head == list->tail && list->tail == d) {
                list->head = list->tail = NULL;
            } else if (d == list->head) {
                list->head = d->next;
                list->head->prev = NULL;
            } else if (d == list->tail) {
                list->tail = d->prev;
                list->tail->next = NULL;
            } else {
                e->prev = d->prev;
                e->prev->next = e;
            }
            d->list = NULL;
            if (list->cur == d)
                list->cur = NULL;
            list->length--;
            slice->length--;
            // the callback got the value and will take care of releasing it
            destroy_entry(d);
            if (rc == -2) // -2 means : remove and stop the iteration
                break;
            // -1 instead means that we still want to remove the item
            // but we also want to go ahead with the iteration
        } else {
            e = e->next;
        }
    }
    MUTEX_UNLOCK(list->lock);
    return idx;
}*/

int slice_iterator_callback(void *item, size_t idx, void *user) {
    if (strcmp((char *)user,(char *)item) == 0) {
        return -2;
    }
    else {
        return 1;
    }
}

int main(int argc, char **argv) {

    linked_list_t *list = list_create();

    int i;
    for (i = 1; i <= 4; i++) {
        char *val = malloc(100);
        sprintf(val, "test%d", i);
        list_push_value(list, val);
    }

    slice_t *slice = slice_create(list, 0, list_count(list));

    char *find = "test1";
    int count = 0;
    int pos = slice_foreach_value(slice, slice_iterator_callback, find);
    list_push_value(list, find);

    
    for (i = 0; i < 4; i++) {
        char *val = malloc(100);
        val = list_shift_value(list);
        printf("val:%s\n",val);
    }
    /*
    printf("cnt %zu\n",list_count(list));
    
    list_push_value(list, strdup("test2"));
    printf("cnt %zu\n",list_count(list));
    char *v = list_pop_value(list);
    printf("val:%s\n",v);
    */
}

cache2 * create_cache() {
    return NULL;
}
void set(cache2 * cache, char * key, char ** value, int valueLen) {
    printf("Set cache\n");
}
bool get(cache2 * cache, char * key, char ** value) {
    printf("Get cache\n");
    return false;
}