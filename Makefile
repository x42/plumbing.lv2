#!/usr/bin/make -f

# these can be overridden using make variables. e.g.
#   make CFLAGS=-O2
# or
#   make install LV2DIR=$HOME/.lv2/

OPTIMIZATIONS ?= -msse -msse2 -mfpmath=sse -ffast-math -fomit-frame-pointer -O3 -fno-finite-math-only
DESTDIR ?=
PREFIX ?= /usr/local
CFLAGS ?= $(OPTIMIZATIONS) -Wall -g
LV2DIR ?= $(PREFIX)/lib/lv2
STRIP  ?= strip
PKG_CONFIG ?= pkg-config

###############################################################################
# HERE BE DRAGONS
###############################################################################

BUILDDIR=build/
LOADLIBES=
LV2NAME=plumbing
BUNDLE=plumbing.lv2

###############################################################################
# build-system, dependencies & architecture

STRIPFLAGS=-s

STRIPDEPS=
DSPDEPS=midieat.c route.c

UNAME=$(shell uname)
ifeq ($(UNAME),Darwin)
  LV2LDFLAGS=-dynamiclib
  LIB_EXT=.dylib
  STRIPFLAGS=-u -r -arch all -s $(BUILDDIR)lv2syms
  STRIPDEPS=$(BUILDDIR)lv2syms
  ifeq ($(shell $(CC) --version | grep -q LLVM && echo clang),clang) 
    STRIP=/usr/bin/true
    override CFLAGS += -exported_symbols_list=$(STRIPDEPS)
  endif
else
  LV2LDFLAGS=-Wl,-Bstatic -Wl,-Bdynamic
  LIB_EXT=.so
endif

ifneq ($(XWIN),)
  CC=$(XWIN)-gcc
  STRIP=$(XWIN)-strip
  LV2LDFLAGS=-Wl,-Bstatic -Wl,-Bdynamic -Wl,--as-needed
  LIB_EXT=.dll
  override LDFLAGS += -static-libgcc
endif

# check for build-dependencies
ifeq ($(shell $(PKG_CONFIG) --exists lv2 || echo no), no)
  $(error "LV2 SDK was not found")
endif

override CFLAGS += -fPIC -std=c99
override CFLAGS += `$PKG_CONFIG) --cflags lv2`

ifeq ($(shell $(PKG_CONFIG) --atleast-version=1.18.6 lv2 && echo yes), yes)
  override CFLAGS += -DHAVE_LV2_1_18_6
endif

###############################################################################
# build target definitions

default: all

all: $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(BUILDDIR)$(LV2NAME)$(LIB_EXT)

$(BUILDDIR)$(LV2NAME)$(LIB_EXT): $(LV2NAME).c $(DSPDEPS) $(STRIPDEPS)
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) \
	  -o $(BUILDDIR)$(LV2NAME)$(LIB_EXT) $(LV2NAME).c \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(LOADLIBES)
	$(STRIP) $(STRIPFLAGS) $(BUILDDIR)$(LV2NAME)$(LIB_EXT)

$(BUILDDIR)lv2syms:
	@mkdir -p $(BUILDDIR)
	echo "_lv2_descriptor" > $(BUILDDIR)lv2syms

###############################################################################
# LV2 turtle

$(BUILDDIR)manifest.ttl: Makefile
	@mkdir -p $(BUILDDIR)
	# generating manifest
	@echo "@prefix lv2:  <http://lv2plug.in/ns/lv2core#> ." > $(BUILDDIR)manifest.ttl
	@echo "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ." >> $(BUILDDIR)manifest.ttl
	@for p in $(shell seq 1 4); do \
		echo "<http://gareus.org/oss/lv2/$(LV2NAME)#eat$$p>" >> $(BUILDDIR)manifest.ttl; \
		echo "  a lv2:Plugin ;" >> $(BUILDDIR)manifest.ttl ;\
		echo "  lv2:binary <$(LV2NAME)$(LIB_EXT)>;" >> $(BUILDDIR)manifest.ttl; \
		echo "  rdfs:seeAlso <$(LV2NAME).ttl> ." >> $(BUILDDIR)manifest.ttl; \
	done
	@for p in $(shell seq 1 4); do \
		echo "<http://gareus.org/oss/lv2/$(LV2NAME)#gen$$p>" >> $(BUILDDIR)manifest.ttl; \
		echo "  a lv2:Plugin ;" >> $(BUILDDIR)manifest.ttl ;\
		echo "  lv2:binary <$(LV2NAME)$(LIB_EXT)>;" >> $(BUILDDIR)manifest.ttl; \
		echo "  rdfs:seeAlso <$(LV2NAME).ttl> ." >> $(BUILDDIR)manifest.ttl; \
	done
	@for rin in `seq 1 4`; do  for rout in `seq 1 4`; do \
		if test $${rin} -eq 1 -a $${rout} -eq 1; then continue; fi;\
		echo "<http://gareus.org/oss/lv2/$(LV2NAME)#route_$${rin}_$${rout}>" >> $(BUILDDIR)manifest.ttl; \
		echo "  a lv2:Plugin ;" >> $(BUILDDIR)manifest.ttl ;\
		echo "  lv2:binary <$(LV2NAME)$(LIB_EXT)>;" >> $(BUILDDIR)manifest.ttl; \
		echo "  rdfs:seeAlso <$(LV2NAME).ttl> ." >> $(BUILDDIR)manifest.ttl; \
	done; done


# NB. the shell scripts are close to max  sh -c "" length
$(BUILDDIR)$(LV2NAME).ttl: ttl/$(LV2NAME).ttl.in Makefile
	@mkdir -p $(BUILDDIR)
	# generating TTL #eat
	@cat ttl/$(LV2NAME).ttl.in > $(BUILDDIR)$(LV2NAME).ttl
	@for p in $(shell seq 1 4); do \
		echo "<http://gareus.org/oss/lv2/$(LV2NAME)#eat$$p>" >> $(BUILDDIR)$(LV2NAME).ttl; \
		echo " a lv2:Plugin, lv2:MixerPlugin, doap:Project;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:license <http://usefulinc.com/doap/licenses/gpl>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:maintainer <http://gareus.org/rgareus#me>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:name \"Midi Remover (+$$p audio)\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:requiredFeature urid:map;"  >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:optionalFeature lv2:hardRTCapable;"  >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:microVersion 0; lv2:minorVersion 1;"  >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:port" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " [" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  a atom:AtomPort, lv2:InputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  atom:bufferType atom:Sequence;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:designation lv2:control;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  atom:supports <http://lv2plug.in/ns/ext/midi#MidiEvent>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:index 0;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:symbol \"midiin\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:name \"MIDI In\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
		PN=1;\
		for n in `seq 1 $$p`; do\
			echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  a lv2:AudioPort, lv2:InputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"in_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"in_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
			echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  a lv2:AudioPort, lv2:OutputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"out_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"out $$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
		done;\
		echo " ]" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " ." >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "" >> $(BUILDDIR)$(LV2NAME).ttl;\
	done
	# generating TTL #gen
	@for p in $(shell seq 1 4); do \
		echo "<http://gareus.org/oss/lv2/$(LV2NAME)#gen$$p>" >> $(BUILDDIR)$(LV2NAME).ttl; \
		echo " a lv2:Plugin, lv2:MixerPlugin, doap:Project;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:license <http://usefulinc.com/doap/licenses/gpl>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:maintainer <http://gareus.org/rgareus#me>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:name \"Silent Midi Port (+$$p audio)\";" >> $(BUILDDIR)$(LV2NAME).ttl; \
		echo " lv2:requiredFeature urid:map;"  >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:optionalFeature lv2:hardRTCapable;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:microVersion 0; lv2:minorVersion 1;"  >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:port" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " [" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  a atom:AtomPort, lv2:OutputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  atom:bufferType atom:Sequence;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:designation lv2:control;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  atom:supports <http://lv2plug.in/ns/ext/midi#MidiEvent>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:index 0;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:symbol \"midout\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "  lv2:name \"MIDI Out\"" >> $(BUILDDIR)$(LV2NAME).ttl;\
		PN=1;\
		for n in `seq 1 $$p`; do\
			echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  a lv2:AudioPort, lv2:InputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"in_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"in_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
			echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  a lv2:AudioPort, lv2:OutputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"out_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"out $$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
		done;\
		echo " ]" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " ." >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "" >> $(BUILDDIR)$(LV2NAME).ttl;\
	done
	# generating TTL #route
	@for rin in `seq 1 4`; do  for rout in `seq 1 4`; do \
		if test $${rin} -eq 1 -a $${rout} -eq 1; then continue; fi;\
		echo "<http://gareus.org/oss/lv2/$(LV2NAME)#route_$${rin}_$${rout}>" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " a lv2:Plugin, lv2:MixerPlugin, doap:Project;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:license <http://usefulinc.com/doap/licenses/gpl>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:maintainer <http://gareus.org/rgareus#me>;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " doap:name \"Route $$rin to $$rout\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:optionalFeature lv2:hardRTCapable;" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:microVersion 0; lv2:minorVersion 1;"  >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " lv2:port" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " [" >> $(BUILDDIR)$(LV2NAME).ttl;\
		PN=0;\
		for n in `seq 1 $$rout`; do\
			if test $${PN} -gt 0; then echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl; fi; \
			dflt=$$n; if test $${dflt} -gt $$rin; then dflt=0; fi; \
			echo "  a lv2:ControlPort, lv2:InputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"src_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"Source for Output $$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:portProperty lv2:integer;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:scalePoint [rdfs:label \"off\"; rdf:value 0;];" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:minimum 0; lv2:maximum $$rin; lv2:default $$dflt;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
		done;\
		for n in `seq 1 $$rin`; do\
			echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  a lv2:AudioPort, lv2:InputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"in_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"in_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
		done;\
		for n in `seq 1 $$rout`; do\
			echo " ] , [" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  a lv2:AudioPort, lv2:OutputPort;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:index $$PN;" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:symbol \"out_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			echo "  lv2:name \"out_$$n\";" >> $(BUILDDIR)$(LV2NAME).ttl;\
			PN=$$(( $$PN + 1 ));\
		done;\
		echo " ]" >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo " ." >> $(BUILDDIR)$(LV2NAME).ttl;\
		echo "" >> $(BUILDDIR)$(LV2NAME).ttl;\
	done; done


###############################################################################
# install/uninstall/clean definitions

install: all
	install -d $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m755 $(BUILDDIR)$(LV2NAME)$(LIB_EXT) $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m644 $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(DESTDIR)$(LV2DIR)/$(BUNDLE)

uninstall:
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/manifest.ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME).ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME)$(LIB_EXT)
	-rmdir $(DESTDIR)$(LV2DIR)/$(BUNDLE)

clean:
	rm -f $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(BUILDDIR)$(LV2NAME)$(LIB_EXT) $(BUILDDIR)lv2syms
	rm -rf $(BUILDDIR)*.dSYM
	-test -d $(BUILDDIR) && rmdir $(BUILDDIR) || true

.PHONY: clean all install uninstall
