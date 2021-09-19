/* File MSNLIB.C
 * Replacement for C library for use with MS-DOS Kermit.
 *
 *	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
 *	City of New York.  The MS-DOS Kermit software may not be, in whole 
 *	or in part, licensed or sold for profit as a software product itself,
 *	nor may it be included in or distributed with commercial products
 *	or otherwise distributed by commercial concerns to their clients 
 *	or customers without written permission of the Office of Kermit 
 *	Development and Distribution, Columbia University.  This copyright 
 *	notice must not be removed, altered, or obscured.
 *
 * Last edit
 * 12 Jan 1995 v3.14
 *  Authors: J.R.Doupnik, USU, Frank da Cruz, Columbia Univ.
 * Contains:
 * strchr, strcat, strncat, strcpy, strncpy, strlen, strcmp, stricmp, strncmp
 * atoi, itoa, ltoa, isdigit, ntoa.
*/
#include "msntcp.h"
#include "msnlib.h"

#ifndef MSDOS
/*
 In MS-DOS Kermit, these are assembler routines to avoid math library.
*/
#define ourmod(a,b)   (a % b)
#define ourdiv(a, b)  (a / b)
#define ourlmod(a,b)  (a % b)
#define ourldiv(a, b) (a / b)
#endif /* MSDOS */

#ifndef NULL
#define NULL 0
#endif /* NULL */

/*
 By the way, there is probably no point in the next #ifndef,
 because size_t is either built into to the compiler or typedef'd,
 rather than defined.  So the #define below will always happen.
*/
#ifndef size_t
#define size_t int
#endif /* size_t */

int _acrtused;			/* MS C compiler startup file quantity */

/*
  _strchr
  Finds first occurence of character c in string s.
  Returns pointer to it if found, NULL if not found.
*/
byte *
strchr(byte *s, byte c) {
    while ((*s != (byte)'\0') && (*s != (byte)(c & 0xff))) s++;
    if (*s == '\0') return(NULL);
    else return(s);
}

// XXX Kludge for bcc. This probably won't work, but let's see.
// Bruce's cc cannot handle FAR pointers. 
#define FAR
byte FAR *
strchrf(byte FAR *s, byte c) {
    while ((*s != (byte)'\0') && (*s != (byte)(c & 0xff))) s++;
    if (*s == '\0') return(NULL);
    else return(s);
}

/*
  _strcat
  Appends entire string s2 to string s1.
  Assumes there is room for s2 after end of s1.
  Returns pointer to s1 or NULL if s1 is a null pointer.
*/
byte *
strcat(byte *s1, byte *s2) {
    register byte *p;

    if (s1 == NULL) return(NULL);
    if (s2 == NULL || *s2 == '\0') return(s1);
    p = s1;				/* Make copy */
    while (*p) p++;			/* Find end */
    while (*p++ = *s2++);		/* Copy thru terminating NUL */
    return(s1);				/* Return original */
}

/*
  _strncat
  Appends up to n chars of string s2 to string s1.
  Returns pointer to string1 or NULL if s1 is a null pointer.
*/
byte *
strncat(byte *s1, byte *s2, size_t n) {
    register byte * p;

    if (s1 == NULL) return(NULL);
    if (s2 == NULL || *s2 == '\0') return(s1);
    p = s1;				/* Copy pointer */
    while (*p) p++;			/* Step to end of s1 */
    while ((*p++ = *s2++) && (--n > 0)); /* Copy up to n bytes of s2 */
    return(s1);				/* Return original pointer */
}

/*
  _strcpy
  Copies s2 to s1, returns pointer to s1 or NULL if s1 was NULL.
*/
byte *
strcpy(byte *s1, byte *s2) {
    register byte *p;

    if (s1 == NULL) return(NULL);
    if (s2 == NULL) s2 = "";
    p = s1;				/* Copy pointer */
    while (*p++ = *s2++);		/* Copy thru terminating NUL */
    return(s1);				/* Return original pointer */
}

/*
  _strncpy
  Copies at most n characters from s2 to to s1, returns pointer to s1.
  Returns s1 or NULL if s1 was NULL.
*/
byte *
strncpy(byte *s1, byte *s2, size_t n) {
    register int s2len;
    register byte *p1;

    if (s1 == NULL) return(NULL);
    if (s2 == NULL) s2 = "";
    if ((s2len = strlen(s2)) > n) s2len = n;
    p1 = s1;

    while (s2len-- > 0)			/* Copy */
      *p1++ = *s2++;
    *p1 = '\0';				/* Terminate */
    return(s1);				/* No need to pad out, one's enuf */
}

/*
  _strlen
  Returns length of null-terminated string not including '\0'
*/
size_t
strlen(byte *s) {
    register int i = 0;

    if (s == NULL) return(0);
    while (*s++) i++;
    return(i);
}

/*
  _strcmp
  Compare null-terminated strings using ASCII values.
  Case matters.  Returns:
  < 0 if s1 < s2,
  = 0 if s1 = s2,
  > 0 if s1 > s2
*/
int
strcmp(byte *s1, byte *s2) {
    if (s1 == NULL) s1 = "";
    if (s2 == NULL) s2 = "";
    do {
	if (*s1 < *s2) return(-1);
	if (*s1 > *s2) return(1);
	if (*s2 == '\0') return(0);
	s2++;
    } while (*s1++);
    return(0);
}

/*
  _stricmp
  Like strcmp but case insenstive
*/
int
stricmp(byte *s1, byte *s2) {
    register byte c1, c2;

    if (s1 == NULL) s1 = "";
    if (s2 == NULL) s2 = "";
    do {
	c1 = *s1; c2 = *s2;
	if ('a' <= c1 && c1 <= 'z') c1 = c1 - (byte)('a' - 'A');
	if ('a' <= c2 && c2 <= 'z') c2 = c2 - (byte)('a' - 'A');
	if (c1 < c2) return(-1);
	if (c1 > c2) return(1);
	if (c2 == '\0') return(0);
	s1++; s2++;
    } while (c1 != '\0');
    return(0);
}

/*
  _strncmp
  Compares at most n characters of strings s1 and s2.
*/
int
strncmp(byte *s1, byte *s2, size_t n) {	

    if (s1 == NULL) s1 = "";
    if (s2 == NULL) s2 = "";
    while (n-- > 0 && *s1) {
	if (*s1 < *s2) return(-1);
	if (*s1 > *s2) return(1);
	s1++; s2++;
    }
    return(0);
}

/*
  _atoi
  Converts decimal numeric string to integer.
  Breaks on first non-digit or end of string.
  Returns integer.
*/
int
atoi(byte *s) {
    register int i, count;
    count = 0;
    for (i = 0; i < 18; i++) {
	if (*s < '0' || *s > '9') break;
	count *= 10;
	count += *s - '0';		/* ascii to binary */
	s++;
    }
    return(count);
}

/*
  _itoa
  Converts integer value to ASCII digits (up to 18 characters long),
  stores in string, null terminated.  Returns NULL on failure,
  pointer to result on success.
*/
byte *
itoa(int value, byte *string, int radix) { /* From K & R */
    int c, j, sign;
    register int i;
    register byte *s;

    if (string == NULL) return(NULL);
    
    s = string;

    if ((sign = value) < 0)		/* Save sign */
      value = - value;			/* Force value positive */
    i = 0;
    do {
	s[i++] = (byte)(ourmod(value, radix) + '0');
    } while ((value = ourdiv(value, radix)) > 0);

    if (sign < 0)
      s[i++] = '-';
    s[i] = '\0';
    j = strlen(s) -1;
    for (i = 0; i < j; i++, j--) {
	c = s[i];
	if (c > '9') c = c - '9' + 'A' -1;
	s[i] = s[j];
	s[j] = (byte)(c & 0xff);
    }
    return(string);
}

/*
  _ltoa
  Like itoa() but using long value ( < 34 ).
*/
byte *
ltoa(long value, byte *string, int radix) { /* K & R */
    int c, j;
    register int i;
    long sign;
    register byte * s;

    if (string == NULL) return(NULL);
    s = string;

    if ((sign = value) < 0) value = - value; /* value to positive*/
    i = 0;
    do {
	s[i++] = (byte)(ourlmod(value, radix) + '0');
    } while ((value = ourldiv(value, radix)) > 0);

    if (sign < 0)
      s[i++] = '-';
    s[i] = '\0';

    j = strlen(s) - 1;
    for (i = 0; i < j; i++, j--) {
	c = s[i];
	if (c > '9') c = c - '9' + 'A' -1;
	s[i] = s[j];
	s[j] = (byte)(c & 0xff);
    }
    return(string);
}

/*
  _isdigit
  Returns 1 if argument is a decimal digit, 0 otherwise.
*/
int
isdigit(byte c) {
    if ((c & 0xff) < '0' || (c & 0xff) > '9')
      return(0);			/* say is not a digit */
    return(1);
}

/* 
   Convert long val to dotted decimal string at pointer p, does high order
   byte first. Intended to yield dotted decimal IP addresses from longs.
*/
void
ntoa(byte *p, unsigned long val)
{
	register byte *ptr;
	register int i;
	
	ptr = p;
	for (i = 24; i >= 0; i -= 8)
		{
		itoa((int)((val >> i) & 0xff), ptr, 10); /* convert a byte */
		strcat(ptr, ".");			/* dot separator */
		ptr = p + strlen(p);
		}
	*(--ptr) = '\0';			/* remove trailing dot */
}
