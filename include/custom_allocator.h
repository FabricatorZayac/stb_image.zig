#ifndef CUSTOM_ALLOCATOR_H_
#define CUSTOM_ALLOCATOR_H_

void *customMalloc(unsigned long size);
void *customRealloc(void *ptr, unsigned long size);
void customFree(void *ptr);

#endif // !CUSTOM_ALLOCATOR_H_
