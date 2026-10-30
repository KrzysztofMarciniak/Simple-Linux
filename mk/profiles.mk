# ---- profile targets -------------------------------------------------------
bare:
	@$(MAKE) --no-print-directory PROFILE=bare iso

minimal:
	@$(MAKE) --no-print-directory PROFILE=minimal iso

# Remember which profile the rootfs was generated for.
$(STAMP)/profile: FORCE
	@mkdir -p $(STAMP)
	@echo '$(PROFILE)' | cmp -s - $@ || echo '$(PROFILE)' > $@
