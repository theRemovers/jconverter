#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char file_name[]="table/tab_%d.bin\0";


unsigned char max(unsigned char r, unsigned char g, unsigned char b)
{
	unsigned char temp;
	temp = r > g ? r : g;
	return (temp > b ? temp : b);
}

int main(int argc, char *argv[])
{
  	FILE* f_rgb;
  	FILE* f_cry;
  	FILE* f_tab;
  
  	unsigned char r,g,b, y;
  	unsigned char XX,YY,ZZ;
  	char nom_file[256];
  	unsigned char tab[32][32][32];
  	int i,j,k;
  	
  	if (argc > 1)
  	{
  	if ((f_tab = fopen("F:/Program/SebProg/rgb2cry/RGB2CRY.BIN","rb+"))!=NULL)	//table de convertion
 	{
  	for (i = 0; i <= 0x1F; i++)	//
	{
 //		sprintf(nom_file,file_name,i);
  //		f_tab = fopen(nom_file,"rb+");
  		
		for (j = 0; j <= 0x1F; j++)
		{
			for (k = 0; k <= 0x1F; k++)
			{
				tab[i][j][k] = fgetc(f_tab);
			}
		}
//		fclose(f_tab);
 	}
  	
  
  	if ((f_rgb = fopen(argv[1],"rb+"))!=NULL)
  	{
  		strcpy(nom_file,strtok(argv[1],"."));
  		strcat(nom_file,".cry");
  		f_cry = fopen(nom_file,"wb+");
  
  		while (!feof(f_rgb))
  		{
  			r = fgetc(f_rgb);
  			g = fgetc(f_rgb);
  			b = fgetc(f_rgb);
  	
  		y = max(r,g,b);
		
		if (y != 0)
		{
  			XX = ((r * 255) / y)>>3;
  			YY = ((g * 255) / y)>>3;
  			ZZ = ((b * 255) / y)>>3;
		}
		else
		{
  			XX = 0;
  			YY = 0;
  			ZZ = 0;		
		}
  	
		fputc(tab[XX][YY][ZZ],f_cry);
  		fputc(y,f_cry);  	
  	}
  
  	fclose(f_rgb);
  	fclose(f_cry);
  	}
  	}
  	else
  		printf("plante !!!\n");
  	}
  	
  	system("PAUSE");	
  	return 0;
}
