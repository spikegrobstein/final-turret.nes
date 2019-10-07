project=final-turret

srcdir=src
imgdir=img

bg_varfile=$(srcdir)/bg_vars.inc
sprite_varfile=$(srcdir)/sprite_vars.inc

sourcefiles= \
	$(srcdir)/$(project).s \
	$(bg_varfile) \
	$(sprite_varfile) \
	$(srcdir)/zeropage.inc \
	$(srcdir)/tiles.inc \
	$(srcdir)/rodata.inc \
	$(srcdir)/main.inc \
	$(srcdir)/constants.inc \
	$(srcdir)/turret_positions.inc

background_images= \
	$(imgdir)/char.png \
	$(imgdir)/bg_tiles.png

sprite_images= \
	$(imgdir)/sprite_tiles.png \
	$(imgdir)/reticle.png

chrfiles= \
	$(srcdir)/sprites.chr \
	$(srcdir)/background.chr


$(project).nes: $(project).o $(project).cfg
	ld65 -o $@ -C $(project).cfg $(project).o -m $(project).map.txt -Ln $(project).labels.txt --dbgfile $(project).nes.dbg

$(project).o: $(sourcefiles) $(chrfiles)
	ca65 $(srcdir)/$(project).s -g -o $(project).o

$(bg_varfile): $(imgdir)/background.png
$(sprite_varfile): $(imgdir)/sprites.png

$(imgdir)/sprites.png: $(sprite_images)
	tilec --varfile $(sprite_varfile) --outfile $@ $^

$(imgdir)/background.png: $(background_images)
	tilec --varfile $(bg_varfile) --outfile $@ $^

$(srcdir)/sprites.chr: $(imgdir)/sprites.png
	png2chr --size 256 --outdir $(srcdir) $^

$(srcdir)/background.chr: $(imgdir)/background.png
	png2chr --size 256 --outdir $(srcdir) $^

$(srcdir)/turret_positions.inc:
	./scripts/gen_trajectories.rb > $@

run: $(project).nes
	fceuxdsp $^

clean:
	rm -rf \
		$(project).o \
		$(project).nes \
		$(project).map.txt \
		$(project).labels.txt \
		$(project).nes.ram.nl \
		$(project).nes.0.nl \
		$(project).nes.1.nl \
		$(project).nes.dbg \
		$(chrfiles) \
		$(imgdir)/background.png \
		$(imgdir)/sprites.png \
		$(varfile)

.PHONY:
