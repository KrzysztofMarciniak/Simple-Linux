# ---- Mozilla CA certificates for verified HTTPS -------------------------
CA_CERTS_VERSION := 2026-10-20
CA_CERTS_URL := https://curl.se/ca/cacert-$(CA_CERTS_VERSION).pem
CA_CERTS_FILE := $(DL)/cacert-$(CA_CERTS_VERSION).pem

.PHONY: ca-certs
ifeq ($(PROFILE),minimal)
ca-certs: $(STAMP)/ca-certs.rootfs

$(CA_CERTS_FILE):
	@mkdir -p $(DL)
	curl -fL --retry 3 -o $@.part $(CA_CERTS_URL)
	@mv $@.part $@

$(STAMP)/ca-certs.rootfs: $(CA_CERTS_FILE) $(STAMP)/openssl.rootfs \
                          $(STAMP)/rootfs.done $(CURDIR)/mk/ca-certs.mk
	mkdir -p $(ROOTFS)/etc/ssl/certs
	install -m 0644 $(CA_CERTS_FILE) $(ROOTFS)/etc/ssl/cert.pem
	ln -sf ../cert.pem $(ROOTFS)/etc/ssl/certs/ca-certificates.crt
	@touch $@
endif
