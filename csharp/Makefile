CSHARP=gmcs

SRCS=tga2cry.cs configuration.cs

LIBS=/reference:System.Drawing

TARGET=converter

$(TARGET): $(SRCS)
	$(CSHARP) /nologo $(LIBS) /out:$@ $^

.PHONY: clean

clean:
	rm -f $(TARGET) *~
