from pathlib import Path
import pypdfium2 as pdfium
from PIL import Image, ImageOps, ImageDraw

target=Path('tmp/pdf-review'); target.mkdir(parents=True,exist_ok=True)
for file in Path('.').glob('*.pdf'):
    doc=pdfium.PdfDocument(file)
    thumbs=[]
    for n,page in enumerate(doc):
        img=page.render(scale=0.55).to_pil().convert('RGB')
        img.thumbnail((320,390))
        tile=Image.new('RGB',(340,420),'#dddddd'); tile.paste(img,((340-img.width)//2,20))
        ImageDraw.Draw(tile).text((10,400),f'Página {n+1}',fill='black')
        thumbs.append(tile)
    for offset in range(0,len(thumbs),9):
        batch=thumbs[offset:offset+9]; sheet=Image.new('RGB',(1020,420*((len(batch)+2)//3)),'white')
        for n,img in enumerate(batch): sheet.paste(img,((n%3)*340,(n//3)*420))
        sheet.save(target/f'{file.stem}-{offset//9}.png')
print('Previews ready')
